
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#define PONY_WANT_ATOMIC_DEFS

#include "scheduler.h"
#include "mpmcq.h"
#include "pagemap.h"
#include "memory.h"
#include "cpu.h"
#include "actor.h"
#include <string.h>
#include <stdio.h>
#include "threads.h"

#ifndef PLATFORM_IS_APPLE
#define QOS_CLASS_USER_INITIATED 0
#define QOS_CLASS_UTILITY 1
#endif

PONY_MUTEX injectLock = NULL;
PONY_MUTEX injectHighPerformanceLock = NULL;
PONY_MUTEX injectHighEfficiencyLock = NULL;

#ifdef PLATFORM_IS_APPLE
extern void *objc_autoreleasePoolPush();
extern void objc_autoreleasePoolPop(void *);
#endif

extern int pony_root_num_active_remotes();

static DECLARE_THREAD_FN(run_thread);

// Scheduler global data.
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

static PONY_MUTEX sched_mut;

static void pony_register_thread(void);

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
    ponyint_mutex_lock(injectLock);
    pony_actor_t* actor = ponyint_mpmcq_pop(&sched->q);
    ponyint_mutex_unlock(injectLock);
    return actor;
}

/**
 * Puts an actor on the scheduler queue.
 */
static void push(scheduler_t* sched, pony_actor_t* actor)
{
    switch (actor->coreAffinity) {
        case kCoreAffinity_OnlyPerformance:
        case kCoreAffinity_OnlyEfficiency:
            if (actor->coreAffinity != sched->coreAffinity) {
                if (actor->coreAffinity == kCoreAffinity_OnlyPerformance) {
                    //ponyint_mutex_lock(injectHighPerformanceLock);
                    ponyint_mpmcq_push(&injectHighPerformance, actor);
                    //ponyint_mutex_unlock(injectHighPerformanceLock);
                } else {
                    //ponyint_mutex_lock(injectHighEfficiencyLock);
                    ponyint_mpmcq_push(&injectHighEfficiency, actor);
                    //ponyint_mutex_unlock(injectHighEfficiencyLock);
                }
                return;
            }
            break;
        case kCoreAffinity_PreferEfficiency:
            if (sched->coreAffinity == kCoreAffinity_OnlyPerformance) {
                //ponyint_mutex_lock(injectHighEfficiencyLock);
                ponyint_mpmcq_push(&injectHighEfficiency, actor);
                //ponyint_mutex_unlock(injectHighEfficiencyLock);
                return;
            }
            break;
        case kCoreAffinity_PreferPerformance:
            if (sched->coreAffinity == kCoreAffinity_OnlyEfficiency) {
                //ponyint_mutex_lock(injectHighPerformanceLock);
                ponyint_mpmcq_push(&injectHighPerformance, actor);
                //ponyint_mutex_unlock(injectHighPerformanceLock);
                return;
            }
            break;
    }
    ponyint_mpmcq_push_single(&sched->q, actor);
}

/**
 * Handles the global queue and then pops from the local queue
 */
static pony_actor_t* pop_global(scheduler_t* my_sched, scheduler_t* other_sched)
{
    ponyint_mutex_lock(injectLock);
    pony_actor_t* actor = (pony_actor_t*)ponyint_mpmcq_pop(&inject);
    ponyint_mutex_unlock(injectLock);
    
    if(actor != NULL)
        return actor;
    
    switch (my_sched->coreAffinity) {
        case kCoreAffinity_OnlyPerformance:
            ponyint_mutex_lock(injectHighPerformanceLock);
            actor = (pony_actor_t*)ponyint_mpmcq_pop(&injectHighPerformance);
            ponyint_mutex_unlock(injectHighPerformanceLock);
            break;
        case kCoreAffinity_OnlyEfficiency:
            ponyint_mutex_lock(injectHighEfficiencyLock);
            actor = (pony_actor_t*)ponyint_mpmcq_pop(&injectHighEfficiency);
            ponyint_mutex_unlock(injectHighEfficiencyLock);
            break;
    }
    if(actor != NULL)
        return actor;
    
    if (other_sched != NULL)
        return pop(other_sched);
    return NULL;
}

static scheduler_t* choose_victim(scheduler_t* sched)
{
    if (sched == NULL) {
        return NULL;
    }
    
    // we have work to do or the global inject does, we can return right away
    if(sched->last_victim != NULL && sched->last_victim->q.num_messages > 0) {
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

void check_memory_usage(scheduler_t* sched, bool now) {
    if(sched->index == 0) {
        static int not_all_the_time = 0;
        not_all_the_time++;
        if (now || (not_all_the_time % 1000 == 0)) {
            ponyint_update_memory_usage();
        }
    }
}

/**
 * Use mpmcqs to allow stealing directly from a victim, without waiting for a
 * response.
 */
static pony_actor_t* steal(scheduler_t* sched)
{
    pony_actor_t* actor = NULL;
    scheduler_t* victim = NULL;
    /*
#if TARGET_OS_IPHONE
    int scaling_sleep = 0;
    int scaling_sleep_delta = 250;
    int scaling_sleep_min = 500;      // The minimum value we start actually sleeping at
    int scaling_sleep_max = 50000;     // The maximimum amount of time we are allowed to sleep at any single call
#else
    int scaling_sleep = 0;
    int scaling_sleep_delta = 1;
    int scaling_sleep_min = 50;      // The minimum value we start actually sleeping at
    int scaling_sleep_max = 50000;     // The maximimum amount of time we are allowed to sleep at any single call
#endif
     */
    int scaling_sleep = 0;
    int scaling_sleep_delta = 4;
    int scaling_sleep_min = 50;      // The minimum value we start actually sleeping at
    int scaling_sleep_max = 500000;     // The maximimum amount of time we are allowed to sleep at any single call
    
    while(true)
    {
        // Choose the victim with the most work to do
        victim = choose_victim(sched);
        
        if (victim != NULL) {
            actor = pop_global(sched, victim);
            
            // If we stole the wrong actor, throw it back in the sea
            if (actor != NULL && COREAFFINITY_IS_INCOMPATIBLE(actor->coreAffinity, sched->coreAffinity)) {
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
            check_memory_usage(sched, true);
            ponyint_cpu_sleep(scaling_sleep);
        }
        
        if (sched->terminate) {
            return NULL;
        }
        
        sched->idle = true;
    }
    
    sched->idle = false;
    
    return actor;
}

/**
 * Run a scheduler thread until termination.
 */
static void run(scheduler_t* sched)
{
    pony_actor_t* actor = pop_global(sched, sched);
    
#ifdef PLATFORM_IS_APPLE
    autorelease_pool = objc_autoreleasePoolPush();
#endif
    
    while(true) {
        
        check_memory_usage(sched, false);
        
        if(actor == NULL) {
            actor = pop_global(sched, sched);
        }
        if(actor == NULL) {
            actor = steal(sched);
        }
        if(actor != NULL) {
            sched->idle = false;
            
            if (COREAFFINITY_IS_INCOMPATIBLE(actor->coreAffinity, sched->coreAffinity)) {
                push(sched, actor);
                actor = NULL;
                continue;
            }
            
            // Run the current actor and get the next actor.
            // result < 0 means the actor was destroyed (pointer invalid)
            // result == 0 means don't reschedule the actor
            // result > 0 means to reschedule the actor
            int result = ponyint_actor_run(&sched->ctx, actor, actor->batchSize);
                        
            pony_actor_t* next = pop_global(sched, sched);
            
#ifdef PLATFORM_IS_APPLE
            autorelease_pool_is_dirty = true;
#endif
            
            if(result == 1 && actor->suspended == false) {
                bool actor_did_yield = actor->yield;
                actor->yield = false;
                
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
                    if (COREAFFINITY_IS_PREFERENTIAL(actor->coreAffinity)) {
                        // If we prefer a different affinity, check to see if one of those schedulers
                        // is idle, if it is send this actor over to them
                        int targetAffinity = COREAFFINITY_PREFER_TO_ONLY(actor->coreAffinity);
                        if (targetAffinity != sched->coreAffinity) {
                            for (int i = 0; i < scheduler_count; i++){
                                if (scheduler[i].idle == true && scheduler[i].coreAffinity == targetAffinity) {
                                    push(sched, actor);
                                    actor = NULL;
                                    break;
                                }
                            }
                        }
                    }
                }
            } else {
                // We aren't rescheduling, so run the next actor. This may be NULL if our
                // queue was empty.
                actor = next;
            }
            
#ifdef PLATFORM_IS_APPLE
            if (autorelease_pool_is_dirty) {
                objc_autoreleasePoolPop(autorelease_pool);
                autorelease_pool = objc_autoreleasePoolPush();
                autorelease_pool_is_dirty = false;
            }
#endif
        } else if(sched->terminate) {
            break;
        }
    }
}

static DECLARE_THREAD_FN(run_thread)
{
    scheduler_t* sched = (scheduler_t*) arg;
    this_scheduler = sched;
    
    ponyint_thead_setname(sched->index, sched->coreAffinity);
    
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
    }
    
    ponyint_pool_free(scheduler, scheduler_count * sizeof(scheduler_t));
    scheduler = NULL;
    scheduler_count = 0;
    atomic_store_explicit(&active_scheduler_count, 0, memory_order_relaxed);
    
    ponyint_mpmcq_destroy(&inject);
    ponyint_mpmcq_destroy(&injectHighEfficiency);
    ponyint_mpmcq_destroy(&injectHighPerformance);
    
    //pony_syslog2("Flynn", "max memory usage: %0.2f MB\n", ponyint_max_memory() / (1024.0f * 1024.0f));
}

pony_ctx_t* ponyint_sched_init(int force_scheduler_count, int minimum_scheduler_count)
{
    pony_register_thread();
    
    uint32_t threads = ponyint_core_count();
    
    if (minimum_scheduler_count < 4) {
        minimum_scheduler_count = 4;
    }
    
    scheduler_count = threads;
    if (scheduler_count < minimum_scheduler_count) {
        pony_syslog2("Flynn", "Minimum scheduler count of %d activated (only %d hardware cores available)", minimum_scheduler_count, threads);
        scheduler_count = minimum_scheduler_count;
    }
    
    if (force_scheduler_count > 1) {
        scheduler_count = force_scheduler_count;
    }
    
    atomic_store_explicit(&active_scheduler_count, scheduler_count, memory_order_relaxed);
    atomic_store_explicit(&active_scheduler_count_check, scheduler_count, memory_order_relaxed);
    scheduler = (scheduler_t*)ponyint_pool_alloc(scheduler_count * sizeof(scheduler_t));
    memset(scheduler, 0, scheduler_count * sizeof(scheduler_t));
    
    if (sched_mut == NULL) {
        sched_mut = ponyint_mutex_create();
        injectLock = ponyint_mutex_create();
        injectHighPerformanceLock = ponyint_mutex_create();
        injectHighEfficiencyLock = ponyint_mutex_create();
    }
    
    for(uint32_t i = 0; i < scheduler_count; i++)
    {
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
    for(uint32_t i = start; i < scheduler_count; i++)
    {
        int qos = QOS_CLASS_USER_INITIATED;
        scheduler[i].coreAffinity = kCoreAffinity_OnlyPerformance;
        
        if (i < ponyint_e_core_count()) {
            qos = QOS_CLASS_UTILITY;
            scheduler[i].coreAffinity = kCoreAffinity_OnlyEfficiency;
        }
        
        if(!ponyint_thread_create(&scheduler[i].tid, run_thread, qos, &scheduler[i]))
            return false;
    }
    
    return true;
}

void ponyint_sched_wait(bool waitForRemotes)
{
    // block until no local actors or remote actors are in existance for
    // for the specified amount of time.
    int32_t usSleep = 5000;
    int32_t numRepeatIdle = (1000 * 1000) / usSleep;
    int32_t timesIdle = numRepeatIdle;
    
    while(true) {
        uint32_t active = 0;
        
        for(uint32_t i = 0; i < scheduler_count; i++) {
            if (scheduler[i].idle == false) {
                active += 1;
            }
        }
        
        // in order to be able to shutdown, all schedules must be idle
        // all injection queues must be empty
        // all remote actors must be destroyed
        /*
         pony_syslog2("Flynn", "%d  %d  %d  %d  %d\n",
                active,
                (int)inject.num_messages,
                (int)injectHighEfficiency.num_messages,
                (int)injectHighPerformance.num_messages,
                pony_root_num_active_remotes() );
         */
        if (active == 0 &&
            inject.num_messages == 0 &&
            injectHighEfficiency.num_messages == 0 &&
            injectHighPerformance.num_messages == 0 &&
            (waitForRemotes == false || pony_root_num_active_remotes() == 0)) {
            timesIdle--;
            if (timesIdle <= 0) {
                break;
            }
        } else {
            timesIdle = numRepeatIdle;
        }
        
        ponyint_cpu_sleep(usSleep);
    }
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
    this_scheduler = ponyint_pool_alloc(sizeof(scheduler_t));
    memset(this_scheduler, 0, sizeof(scheduler_t));
    this_scheduler->tid = ponyint_thread_self();
    this_scheduler->index = -1;
}

void pony_unregister_thread()
{
    if(this_scheduler == NULL)
        return;
    
    ponyint_pool_free(this_scheduler, sizeof(scheduler_t));
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
