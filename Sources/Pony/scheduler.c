
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
#include <stdlib.h>
#include <time.h>
#include "threads.h"

#define PONY_PROFILE_MAX_TYPES 1024

typedef struct prof_bucket_t { uint64_t ns; uint64_t count; } prof_bucket_t;

static prof_bucket_t* g_prof = NULL;
static PONY_ATOMIC(bool) g_prof_enabled = false;

void pony_profiler_enable(bool on)
{
    atomic_store_explicit(&g_prof_enabled, on, memory_order_relaxed);
}

#ifndef PLATFORM_IS_APPLE
#define QOS_CLASS_USER_INITIATED 0
#define QOS_CLASS_UTILITY 1
#endif

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

void pony_profiler_reset(void)
{
    if (g_prof == NULL) { return; }
    memset(g_prof, 0,
           (size_t)scheduler_count * PONY_PROFILE_MAX_TYPES * sizeof(prof_bucket_t));
}

int pony_profiler_max_types(void)
{
    return PONY_PROFILE_MAX_TYPES;
}

int pony_profiler_collect(uint64_t* outNs, uint64_t* outCount, int maxTypes)
{
    int n = maxTypes < PONY_PROFILE_MAX_TYPES ? maxTypes : PONY_PROFILE_MAX_TYPES;
    for (int t = 0; t < n; t++) { outNs[t] = 0; outCount[t] = 0; }
    if (g_prof == NULL) { return n; }
    for (uint32_t s = 0; s < scheduler_count; s++) {
        prof_bucket_t* row = &g_prof[(size_t)s * PONY_PROFILE_MAX_TYPES];
        for (int t = 0; t < n; t++) {
            outNs[t]    += row[t].ns;
            outCount[t] += row[t].count;
        }
    }
    return n;
}
static mpmcq_t inject;
static mpmcq_t injectHighPerformance;
static mpmcq_t injectHighEfficiency;

// Cleared before the scheduler array is torn down. wake_one_sleeper() can be
// called from threads that are not schedulers -- the timer loop, remote node
// threads, the main thread -- and those threads are not joined before
// ponyint_sched_shutdown() frees the array, so without this they can dereference
// freed scheduler_t memory and lock a destroyed mutex.
static PONY_ATOMIC(bool) schedulers_running;

// Number of schedulers currently parked. Read on every push, so the common
// loaded case -- nobody parked -- costs a single load of a line that stays
// shared across cores rather than a scan.
static PONY_ATOMIC(int32_t) sleeping_count;

// Wake one parked scheduler that is actually able to service the queue the
// caller just pushed to.
//
// for_affinity is the affinity a scheduler must have to be able to pop that
// queue:
//
//   kCoreAffinity_OnlyEfficiency  -> injectHighEfficiency, E schedulers only
//   kCoreAffinity_OnlyPerformance -> injectHighPerformance, P schedulers only
//   kCoreAffinity_None            -> inject, or a scheduler's own q; anyone
//
// The filter is not an optimisation, it is required for liveness. Both
// pop_global() and work_available() are affinity-filtered, so waking a
// scheduler of the wrong class is strictly worse than waking nobody: it finds
// nothing, parks again, and -- because we wake exactly one -- the scheduler that
// could have run the actor is never signalled at all. The work then waits out a
// backstop timeout (up to park_timeout_max) instead of being picked up
// immediately. ponyint_sched_start() assigns the E affinities to the low
// indices, so an unfiltered scan starting at 0 hit precisely that case for
// every injectHighPerformance push.
static void wake_one_sleeper(int32_t for_affinity)
{
    if(atomic_load_explicit(&schedulers_running, memory_order_acquire) == false)
        return;

    if(scheduler == NULL)
        return;

    atomic_thread_fence(memory_order_seq_cst);

    if(atomic_load_explicit(&sleeping_count, memory_order_relaxed) <= 0)
        return;

    // Wake exactly one. Waking all of them would have every scheduler contend
    // for a single actor and go straight back to sleep; a scheduler that finds
    // work and discovers more will push it, which wakes the next one in turn.
    for(uint32_t i = 0; i < scheduler_count; i++)
    {
        if(for_affinity != kCoreAffinity_None &&
           scheduler[i].coreAffinity != for_affinity)
            continue;

        if(atomic_load_explicit(&scheduler[i].parked, memory_order_acquire))
        {
            ponyint_park_wake(&scheduler[i].park);
            return;
        }
    }

    // Deliberately no fall back to an incompatible scheduler. If no scheduler of
    // the target class is parked then they are all running, and pop_global()
    // drains the queue when one of them next comes up for air.
}

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
    return ponyint_mpmcq_pop(&sched->q);
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
                    ponyint_mpmcq_push(&injectHighPerformance, actor);
                } else {
                    ponyint_mpmcq_push(&injectHighEfficiency, actor);
                }
                // actor->coreAffinity is already exactly the class that can pop
                // the queue we just pushed to.
                wake_one_sleeper(actor->coreAffinity);
                return;
            }
            break;
        case kCoreAffinity_PreferEfficiency:
            if (sched->coreAffinity == kCoreAffinity_OnlyPerformance) {
                ponyint_mpmcq_push(&injectHighEfficiency, actor);
                wake_one_sleeper(kCoreAffinity_OnlyEfficiency);
                return;
            }
            break;
        case kCoreAffinity_PreferPerformance:
            if (sched->coreAffinity == kCoreAffinity_OnlyEfficiency) {
                ponyint_mpmcq_push(&injectHighPerformance, actor);
                wake_one_sleeper(kCoreAffinity_OnlyPerformance);
                return;
            }
            break;
    }
    // Our own queue: stealable by any scheduler, and push() has already routed
    // away anything incompatible with sched, so any sleeper will do.
    ponyint_mpmcq_push_single(&sched->q, actor);
    wake_one_sleeper(kCoreAffinity_None);
}

/**
 * Handles the global queue and then pops from the local queue
 */
static pony_actor_t* pop_global(scheduler_t* my_sched, scheduler_t* other_sched)
{
    pony_actor_t* actor = (pony_actor_t*)ponyint_mpmcq_pop(&inject);
    
    if(actor != NULL)
        return actor;
    
    switch (my_sched->coreAffinity) {
        case kCoreAffinity_OnlyPerformance:
            actor = (pony_actor_t*)ponyint_mpmcq_pop(&injectHighPerformance);
            break;
        case kCoreAffinity_OnlyEfficiency:
            actor = (pony_actor_t*)ponyint_mpmcq_pop(&injectHighEfficiency);
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

void check_memory_usage(scheduler_t* sched) {
    if(sched->index == 0) {
        static int not_all_the_time = 0;
        not_all_the_time++;
        if (not_all_the_time % 1000 == 0) {
            ponyint_update_memory_usage();
        }
    }
}

static bool work_available(scheduler_t* sched)
{
    if(ponyint_mpmcq_num_messages(&inject) > 0)
        return true;

    switch(sched->coreAffinity) {
        case kCoreAffinity_OnlyPerformance:
            if(ponyint_mpmcq_num_messages(&injectHighPerformance) > 0)
                return true;
            break;
        case kCoreAffinity_OnlyEfficiency:
            if(ponyint_mpmcq_num_messages(&injectHighEfficiency) > 0)
                return true;
            break;
    }

    for(uint32_t i = 0; i < scheduler_count; i++)
    {
        if(ponyint_mpmcq_num_messages(&scheduler[i].q) > 0)
            return true;
    }

    return false;
}

static void park_scheduler(scheduler_t* sched, uint64_t timeout_us)
{
    atomic_store_explicit(&sched->parked, true, memory_order_release);
    atomic_fetch_add_explicit(&sleeping_count, 1, memory_order_relaxed);

    atomic_thread_fence(memory_order_seq_cst);

    if(work_available(sched) == false && atomic_load_explicit(&sched->terminate, memory_order_relaxed) == false)
        ponyint_park_wait(&sched->park, timeout_us);

    atomic_store_explicit(&sched->parked, false, memory_order_release);
    atomic_fetch_sub_explicit(&sleeping_count, 1, memory_order_relaxed);
}

/**
 * Use mpmcqs to allow stealing directly from a victim, without waiting for a
 * response.
 */
static pony_actor_t* steal(scheduler_t* sched)
{
    pony_actor_t* actor = NULL;
    scheduler_t* victim = NULL;

    // Backoff policy for a scheduler that has run out of work.
    //
    // Spin briefly first: work often shows up within a few hundred nanoseconds,
    // and a park/unpark round trip costs far more than the spin does. Past that
    // we park, which unlike a sleep can be woken the moment work is pushed.
    //
    // The timeout is a backstop, not the discovery mechanism -- a parked
    // scheduler is woken by wake_one_sleeper(), so wake latency no longer has
    // anything to do with how long we are willing to sleep for. That decoupling
    // is the point: the previous exponential sleep had to trade idle CPU
    // against wake latency, and could not give both.
    const int spin_rounds = 12;
    const uint64_t park_timeout_min = 1000;      // us
    const uint64_t park_timeout_max = 100000;    // us

    int spins = 0;
    uint64_t park_timeout = 0;
    
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
        
        if (spins < spin_rounds) {
            spins++;
        } else {
            // Sample memory on the same throttle the busy path in run() uses.
            check_memory_usage(sched);

            // Ramp the backstop rather than jumping straight to the maximum, so
            // that if a wakeup is ever missed it is caught in a millisecond
            // rather than a tenth of a second.
            park_timeout = (park_timeout == 0) ? park_timeout_min : park_timeout * 2;
            if (park_timeout > park_timeout_max) {
                park_timeout = park_timeout_max;
            }

            park_scheduler(sched, park_timeout);
        }
        
        if (atomic_load_explicit(&sched->terminate, memory_order_relaxed)) {
            return NULL;
        }
        
        atomic_store_explicit(&sched->idle, true, memory_order_relaxed);
    }
    
    atomic_store_explicit(&sched->idle, false, memory_order_relaxed);
    
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
        
        check_memory_usage(sched);
        
        if(actor == NULL) {
            actor = pop_global(sched, sched);
        }
        if(actor == NULL) {
            actor = steal(sched);
        }
        if(actor != NULL) {
            atomic_store_explicit(&sched->idle, false, memory_order_relaxed);
            
            if (COREAFFINITY_IS_INCOMPATIBLE(actor->coreAffinity, sched->coreAffinity)) {
                push(sched, actor);
                actor = NULL;
                continue;
            }
            
            // Run the current actor and get the next actor.
            // result < 0 means the actor was destroyed (pointer invalid)
            // result == 0 means don't reschedule the actor
            // result > 0 means to reschedule the actor

            // Capture profiling state BEFORE the call: a result of -1 means the
            // actor was freed inside ponyint_actor_run, so we must not touch it
            // afterward. The accumulator lives on g_prof (indexed by this
            // scheduler), not on the actor, so it stays valid regardless.
            int32_t  profTypeID = actor->profileTypeID;
            bool     profOn     = atomic_load_explicit(&g_prof_enabled, memory_order_relaxed);
            uint64_t profStart  = profOn ? ponyint_cpu_tick() : 0;

            int result = ponyint_actor_run(&sched->ctx, actor, actor->batchSize);

            if (profOn && g_prof != NULL && profTypeID >= 0 && profTypeID < PONY_PROFILE_MAX_TYPES) {
                prof_bucket_t* b = &g_prof[(size_t)sched->index * PONY_PROFILE_MAX_TYPES + profTypeID];
                b->ns    += (ponyint_cpu_tick() - profStart);   // own thread only -> no atomics
                b->count += 1;
            }
                        
            pony_actor_t* next = pop_global(sched, sched);
            
#ifdef PLATFORM_IS_APPLE
            autorelease_pool_is_dirty = true;
#endif
            
            if(result == 1) {
                bool actor_did_yield =
                    atomic_load_explicit(&actor->yield, memory_order_relaxed);
                
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
                                if (atomic_load_explicit(&scheduler[i].idle, memory_order_relaxed) == true && scheduler[i].coreAffinity == targetAffinity) {
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
        } else if(atomic_load_explicit(&sched->terminate, memory_order_relaxed)) {
            break;
        }
    }
}

static DECLARE_THREAD_FN(run_thread)
{
    scheduler_t* sched = (scheduler_t*) arg;
    this_scheduler = sched;
    
    ponyint_thead_setname(sched->index, sched->coreAffinity);
    ponyint_cpu_apply_thread_affinity(sched->coreAffinity);
    
    run(sched);
    ponyint_pool_thread_cleanup();
    
    return 0;
}

static void ponyint_sched_shutdown()
{
    uint32_t start;
    
    start = 0;
    
    // Stop anyone outside the scheduler threads from reaching into the array
    // before we start tearing it down.
    atomic_store_explicit(&schedulers_running, false, memory_order_release);

    // Signal every scheduler before joining any of them. Setting terminate and
    // joining in the same loop serialises shutdown behind scheduler 0, which
    // matters far more now that a scheduler can be parked: each one would
    // otherwise have to wait out its own backstop timeout in turn.
    for(uint32_t i = start; i < scheduler_count; i++) {
        atomic_store_explicit(&scheduler[i].terminate, true, memory_order_relaxed);
    }
    for(uint32_t i = start; i < scheduler_count; i++) {
        ponyint_park_wake(&scheduler[i].park);
    }
    for(uint32_t i = start; i < scheduler_count; i++) {
        ponyint_thread_join(scheduler[i].tid);
    }
    
    for(uint32_t i = 0; i < scheduler_count; i++)
    {
        while(ponyint_thread_messageq_pop(&scheduler[i].mq) != NULL) { ; }
        ponyint_messageq_destroy(&scheduler[i].mq);
        ponyint_mpmcq_destroy(&scheduler[i].q);
        ponyint_park_destroy(&scheduler[i].park);
    }
    
    ponyint_pool_free(scheduler, scheduler_count * sizeof(scheduler_t));
    scheduler = NULL;

    if (g_prof != NULL) {
        free(g_prof);
        g_prof = NULL;
    }

    scheduler_count = 0;
    atomic_store_explicit(&active_scheduler_count, 0, memory_order_relaxed);
    atomic_store_explicit(&sleeping_count, 0, memory_order_relaxed);
    
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
    
    // Core affinity routing needs both an E and a P scheduler to exist (see
    // ponyint_sched_start). One scheduler cannot be both, so floor the count at
    // two. Nothing should be able to get here with a smaller value -- the
    // minimum is clamped to 4 above and force_scheduler_count is only honoured
    // when > 1 -- but the clamp in ponyint_sched_start relies on this, so make
    // it explicit rather than implied.
    if (scheduler_count < 2) {
        scheduler_count = 2;
    }
    
    atomic_store_explicit(&active_scheduler_count, scheduler_count, memory_order_relaxed);
    atomic_store_explicit(&active_scheduler_count_check, scheduler_count, memory_order_relaxed);
    atomic_store_explicit(&sleeping_count, 0, memory_order_relaxed);
    scheduler = (scheduler_t*)ponyint_pool_alloc(scheduler_count * sizeof(scheduler_t));
    memset(scheduler, 0, scheduler_count * sizeof(scheduler_t));

    // Allocate the per-scheduler profiler matrix (zero-initialized). Uses calloc
    // rather than the pony pool because it is a single large, long-lived buffer.
    g_prof = (prof_bucket_t*)calloc((size_t)scheduler_count * PONY_PROFILE_MAX_TYPES,
                                    sizeof(prof_bucket_t));
    
    if (sched_mut == NULL) {
        sched_mut = ponyint_mutex_create();
    }
    
    for(uint32_t i = 0; i < scheduler_count; i++)
    {
        scheduler[i].ctx.scheduler = &scheduler[i];
        scheduler[i].last_victim = &scheduler[i];
        scheduler[i].index = i;
        ponyint_messageq_init(&scheduler[i].mq);
        ponyint_mpmcq_init(&scheduler[i].q);
        ponyint_park_init(&scheduler[i].park);
        atomic_store_explicit(&scheduler[i].parked, false, memory_order_relaxed);
    }
    
    ponyint_mpmcq_init(&inject);
    ponyint_mpmcq_init(&injectHighEfficiency);
    ponyint_mpmcq_init(&injectHighPerformance);

    // Only now is every park initialised and safe for another thread to touch.
    atomic_store_explicit(&schedulers_running, true, memory_order_release);
    
    return pony_ctx();
}

bool ponyint_sched_start()
{
    pony_register_thread();
    
    uint32_t start = 0;

    // Assign every affinity before creating any thread. wake_one_sleeper() reads
    // scheduler[i].coreAffinity from other threads, and interleaving the
    // assignment with thread creation left scheduler j reading the affinity of
    // scheduler i > j before it had been written.
    uint32_t e_detected = ponyint_e_core_count();
    uint32_t e_schedulers = e_detected;
    
    if (e_schedulers < 1) {
        e_schedulers = 1;
    }
    if (e_schedulers > scheduler_count - 1) {
        e_schedulers = scheduler_count - 1;
    }
    if (e_schedulers != e_detected) {
        pony_syslog2("Flynn",
                     "e_core_count %u out of range for %u schedulers, using %u efficiency schedulers",
                     e_detected, scheduler_count, e_schedulers);
    }
    
    for(uint32_t i = start; i < scheduler_count; i++)
    {
        scheduler[i].coreAffinity = (i < e_schedulers)
            ? kCoreAffinity_OnlyEfficiency
            : kCoreAffinity_OnlyPerformance;
    }
    
    // sanity check we at least have 1 efficiency and 1 performance scheduler
    uint32_t n_e = 0, n_p = 0;
    for(uint32_t i = start; i < scheduler_count; i++)
    {
        if(scheduler[i].coreAffinity == kCoreAffinity_OnlyEfficiency) n_e++; else n_p++;
    }
    if(n_e == 0 || n_p == 0) {
        pony_syslog2("Flynn",
                     "FATAL: %u efficiency / %u performance schedulers -- actors routed to the "
                     "empty class will never run", n_e, n_p);
    }


    for(uint32_t i = start; i < scheduler_count; i++)
    {
        int qos = (scheduler[i].coreAffinity == kCoreAffinity_OnlyEfficiency)
            ? QOS_CLASS_UTILITY
            : QOS_CLASS_USER_INITIATED;
        
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
            if (atomic_load_explicit(&scheduler[i].idle, memory_order_relaxed) == false) {
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
        // push() wakes a sleeper itself
        push(ctx->scheduler, actor);
    } else {
        // Sends from threads that are not schedulers -- the timer loop, remote
        // node threads, the main thread -- land here. pony_register_thread()
        // zeroes its placeholder scheduler_t, so ctx->scheduler is NULL for
        // them and all of their work funnels through the inject queue.
        // Every scheduler pops inject first, regardless of affinity.
        ponyint_mpmcq_push(&inject, actor);
        wake_one_sleeper(kCoreAffinity_None);
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
