//
//  scheduler.c
//  Flynn
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//
// Note: This code is derivative of the Pony runtime; see README.md for more details

#define PONY_WANT_ATOMIC_DEFS

#include "scheduler.h"
#include "mpmcq.h"
#include "pagemap.h"
#include "pool.h"
#include "alloc.h"
#include "cpu.h"
#include "actor.h"
#include <string.h>
#include <stdio.h>
#include "TargetConditionals.h"


static DECLARE_THREAD_FN(run_thread);

// Scheduler global data.
static uint64_t last_cd_tsc;
static uint32_t scheduler_count;
static PONY_ATOMIC(uint32_t) active_scheduler_count;
static PONY_ATOMIC(uint32_t) active_scheduler_count_check;
static scheduler_t* scheduler;
static mpmcq_t inject;
static mpmcq_t injectHighPerformance;
static mpmcq_t injectHighEfficiency;
static __pony_thread_local scheduler_t* this_scheduler;
static __pony_thread_local void* autorelease_pool;
static __pony_thread_local bool autorelease_pool_is_dirty;


static pthread_mutex_t sched_mut;

static pthread_once_t sched_mut_once = PTHREAD_ONCE_INIT;

static void pony_register_thread(void);

void sched_mut_init()
{
    pthread_mutex_init(&sched_mut, NULL);
}

/**
 * Gets the current active scheduler count
 */
uint32_t get_active_scheduler_count()
{
    return atomic_load_explicit(&active_scheduler_count, memory_order_relaxed);
}

/**
 * Gets the next actor from the scheduler queue.
 */
static pony_actor_t* pop(scheduler_t* sched)
{
    return (pony_actor_t*)ponyint_mpmcq_pop(&sched->q);
}

/**
 * Puts an actor on the scheduler queue.
 */
static void push(scheduler_t* sched, pony_actor_t* actor)
{
    if (actor->qualityOfService != kQosAny && actor->qualityOfService != sched->qualityOfService) {
        if (actor->qualityOfService == kQosHighPerformance) {
            ponyint_mpmcq_push(&injectHighPerformance, actor);
        } else {
            ponyint_mpmcq_push(&injectHighEfficiency, actor);
        }
    } else if (actor->qualityOfService == kQosAny && actor->qualityOfService == actor->qualityOfService == kQosHighPerformance) {
        // "any" QoS should favor high efficiency if it can
        ponyint_mpmcq_push(&injectHighEfficiency, actor);
    } else {
        ponyint_mpmcq_push_single(&sched->q, actor);
    }
}

/**
 * Handles the global queue and then pops from the local queue
 */
static pony_actor_t* pop_global(scheduler_t* my_sched, scheduler_t* other_sched)
{
    pony_actor_t* actor = (pony_actor_t*)ponyint_mpmcq_pop(&inject);
    if(actor != NULL)
        return actor;
    if (my_sched->qualityOfService == kQosHighPerformance) {
        actor = (pony_actor_t*)ponyint_mpmcq_pop(&injectHighPerformance);
        if(actor != NULL)
            return actor;
    } else if (my_sched->qualityOfService == kQosHighEfficiency) {
        actor = (pony_actor_t*)ponyint_mpmcq_pop(&injectHighEfficiency);
        if(actor != NULL)
            return actor;
    }
    if (other_sched != NULL)
        return pop(other_sched);
    return NULL;
}

static scheduler_t* choose_victim(scheduler_t* sched)
{
    // we have work to do or the global inject does, we can return right away
    if(sched->last_victim->q.num_messages > 0) {
        return sched->last_victim;
    }

    scheduler_t* victim = sched->last_victim;
    while(true)
    {
      victim--;

      if(victim < scheduler)
        victim = &scheduler[scheduler_count - 1];

      if((victim == sched->last_victim) || (scheduler_count == 1)) {
        sched->last_victim = sched;
        break;
      }
      if(victim == sched) {
        continue;
      }
      sched->last_victim = victim;
      return victim;
    }

    return NULL;
}

/**
 * Use mpmcqs to allow stealing directly from a victim, without waiting for a
 * response.
 */
static pony_actor_t* steal(scheduler_t* sched)
{
    pony_actor_t* actor = NULL;
    scheduler_t* victim = NULL;
    
#if TARGET_OS_IPHONE
    int scaling_sleep = 0;
    int scaling_sleep_delta = 250;
    int scaling_sleep_min = 500;      // The minimum value we start actually sleeping at
    int scaling_sleep_max = 50000;     // The maximimum amount of time we are allowed to sleep at any single call
#else
    int scaling_sleep = 0;
    int scaling_sleep_delta = 50;
    int scaling_sleep_min = 250;      // The minimum value we start actually sleeping at
    int scaling_sleep_max = 50000;     // The maximimum amount of time we are allowed to sleep at any single call
#endif
    
    while(true)
    {
        // Choose the victim with the most work to do
        victim = choose_victim(sched);
        
        if (victim != NULL) {
            actor = pop_global(sched, victim);
            
            // If we stole the wrong actor, throw it back in the sea
            if (actor != NULL && actor->qualityOfService != kQosAny && actor->qualityOfService != sched->qualityOfService) {
                push(sched, actor);
                actor = NULL;
            }
            
            if(actor != NULL)
                break;
        }
        
        scaling_sleep += scaling_sleep_delta;
        if (scaling_sleep > scaling_sleep_max) {
            scaling_sleep = scaling_sleep_max;
        }
        if(scaling_sleep >= scaling_sleep_min) {
            ponyint_cpu_sleep(scaling_sleep);
            if (autorelease_pool_is_dirty) {
                //_objc_autoreleasePoolPrint();
                objc_autoreleasePoolPop(autorelease_pool);
                autorelease_pool = objc_autoreleasePoolPush();
                autorelease_pool_is_dirty = false;
            }
        }
        
        if (sched->terminate) {
            return NULL;
        }
    }
    
    return actor;
}

/**
 * Run a scheduler thread until termination.
 */
static void run(scheduler_t* sched)
{
    if(sched->index == 0)
        last_cd_tsc = 0;
    
    pony_actor_t* actor = pop_global(sched, sched);
    
    autorelease_pool = objc_autoreleasePoolPush();
    
    while(true) {
        
        if(sched->index == 0)
        {
          static int not_all_the_time = 0;
          not_all_the_time++;
          if((not_all_the_time % 100 == 0)) {
            ponyint_update_memory_usage();
          }
        }
        
        if(actor == NULL) {
            actor = pop_global(sched, sched);
        }
        if(actor == NULL) {
            actor = steal(sched);
        }
        if(actor != NULL) {
            
            if (actor->qualityOfService != kQosAny && actor->qualityOfService != sched->qualityOfService) {
                push(sched, actor);
                actor = NULL;
                continue;
            }

            // Run the current actor and get the next actor.
            bool reschedule = ponyint_actor_run(&sched->ctx, actor, 1000);
            
            bool actor_did_yield = actor->yield;
            actor->yield = false;
            
            pony_actor_t* next = pop_global(sched, sched);
            
            autorelease_pool_is_dirty = true;
            
            if(reschedule) {
                if(next != NULL) {
                    if (actor_did_yield == false && actor->priority > next->priority) {
                        // our current actor has a higher priority than the next actor, so put
                        // the next actor back at the end of our queue.  Hopefully someone
                        // else will pick him up
                        push(sched, next);
                    }else{
                        // If we have a next actor, we go on the back of the queue. Otherwise,
                        // we continue to run this actor.
                        push(sched, actor);
                        actor = next;
                    }
                } else {
                    if (actor->qualityOfService != sched->qualityOfService) {
                        push(sched, actor);
                        actor = NULL;
                        continue;
                    }
                }
            } else {
                // We aren't rescheduling, so run the next actor. This may be NULL if our
                // queue was empty.
                actor = next;
            }
        } else if(sched->terminate) {
            break;
        }
    }
}

static DECLARE_THREAD_FN(run_thread)
{
    scheduler_t* sched = (scheduler_t*) arg;
    this_scheduler = sched;
    
    run(sched);
    ponyint_pool_thread_cleanup();
    
    return 0;
}

static void ponyint_sched_shutdown()
{
    uint32_t start;
    
    start = 0;
    
    for(uint32_t i = start; i < scheduler_count; i++) {
        scheduler[i].terminate = true;
        ponyint_thread_join(scheduler[i].tid);
    }
        
    for(uint32_t i = 0; i < scheduler_count; i++)
    {
        while(ponyint_thread_messageq_pop(&scheduler[i].mq) != NULL) { ; }
        ponyint_messageq_destroy(&scheduler[i].mq);
        ponyint_mpmcq_destroy(&scheduler[i].q);
        
        // destroy pthread condition object
        pthread_cond_destroy(scheduler[i].sleep_object);
        
        POOL_FREE(pthread_cond_t, scheduler[i].sleep_object);
        // set sleep condition object to NULL
        scheduler[i].sleep_object = NULL;
    }
    
    ponyint_pool_free_size(scheduler_count * sizeof(scheduler_t), scheduler);
    scheduler = NULL;
    scheduler_count = 0;
    atomic_store_explicit(&active_scheduler_count, 0, memory_order_relaxed);
    
    ponyint_mpmcq_destroy(&inject);
    ponyint_mpmcq_destroy(&injectHighEfficiency);
    ponyint_mpmcq_destroy(&injectHighPerformance);
    
    fprintf(stderr, "max memory usage: %0.2f MB\n", ponyint_max_memory() / (1024.0f * 1024.0f));
}

pony_ctx_t* ponyint_sched_init()
{
    pony_register_thread();
    
    uint32_t threads = ponyint_core_count();
            
    scheduler_count = threads;
    
    atomic_store_explicit(&active_scheduler_count, scheduler_count, memory_order_relaxed);
    atomic_store_explicit(&active_scheduler_count_check, scheduler_count, memory_order_relaxed);
    scheduler = (scheduler_t*)ponyint_pool_alloc_size(scheduler_count * sizeof(scheduler_t));
    memset(scheduler, 0, scheduler_count * sizeof(scheduler_t));
        
    pthread_once(&sched_mut_once, sched_mut_init);
    
    for(uint32_t i = 0; i < scheduler_count; i++)
    {
        // create pthread condition object
        scheduler[i].sleep_object = POOL_ALLOC(pthread_cond_t);
        int ret = pthread_cond_init(scheduler[i].sleep_object, NULL);
        if(ret != 0)
        {
            // if it failed, set `sleep_object` to `NULL` for error
            POOL_FREE(pthread_cond_t, scheduler[i].sleep_object);
            scheduler[i].sleep_object = NULL;
        }
        
        scheduler[i].ctx.scheduler = &scheduler[i];
        scheduler[i].last_victim = &scheduler[i];
        scheduler[i].index = i;
        ponyint_messageq_init(&scheduler[i].mq);
        ponyint_mpmcq_init(&scheduler[i].q);
    }
    
    ponyint_mpmcq_init(&inject);
    ponyint_mpmcq_init(&injectHighEfficiency);
    ponyint_mpmcq_init(&injectHighPerformance);
    
    return pony_ctx();
}

bool ponyint_sched_start()
{
    pony_register_thread();
        
    uint32_t start = 0;
    uint32_t highPerformanceCores = scheduler_count / 2;
    
#if TARGET_OS_IPHONE
    highPerformanceCores = 2;
#endif
    
    for(uint32_t i = start; i < scheduler_count; i++)
    {
        // there was an error creating a wait event or a pthread condition object
        if(scheduler[i].sleep_object == NULL)
            return false;
        
        int qos = QOS_CLASS_USER_INITIATED;
        scheduler[i].qualityOfService = kQosHighPerformance;
        
        if (i < scheduler_count - highPerformanceCores) {
            qos = QOS_CLASS_BACKGROUND;
            scheduler[i].qualityOfService = kQosHighEfficiency;
        }
        
        if(!ponyint_thread_create(&scheduler[i].tid, run_thread, qos, &scheduler[i]))
            return false;
    }
        
    return true;
}

void ponyint_sched_stop()
{
    ponyint_sched_shutdown();
}

void ponyint_sched_add(pony_ctx_t* ctx, pony_actor_t* actor)
{
    if(ctx->scheduler != NULL) {
        push(ctx->scheduler, actor);
    } else {
        ponyint_mpmcq_push(&inject, actor);
    }
}

uint32_t ponyint_sched_cores()
{
    return scheduler_count;
}

uint32_t ponyint_active_sched_count()
{
    return get_active_scheduler_count();
}

void pony_register_thread()
{
    if(this_scheduler != NULL)
        return;
    
    // Create a scheduler_t, even though we will only use the pony_ctx_t.
    this_scheduler = POOL_ALLOC(scheduler_t);
    memset(this_scheduler, 0, sizeof(scheduler_t));
    this_scheduler->tid = ponyint_thread_self();
    this_scheduler->index = -1;
}

void pony_unregister_thread()
{
    if(this_scheduler == NULL)
        return;
    
    POOL_FREE(scheduler_t, this_scheduler);
    this_scheduler = NULL;
    
    ponyint_pool_thread_cleanup();
}

pony_ctx_t* pony_ctx()
{
    if (this_scheduler == NULL) {
        pony_register_thread();
    }
    return &this_scheduler->ctx;
}

// Return the scheduler's index
int32_t pony_sched_index(pony_ctx_t* ctx)
{
    return ctx->scheduler->index;
}
