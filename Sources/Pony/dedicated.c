
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#define PONY_WANT_ATOMIC_DEFS

#include "dedicated.h"
#include "actor.h"
#include "scheduler.h"
#include "messageq.h"
#include "memory.h"
#include "threads.h"
#include "cpu.h"
#include "ponyrt.h"

#include <string.h>
#include <stdio.h>

#ifndef PLATFORM_IS_APPLE
#define QOS_CLASS_USER_INITIATED 0
#define QOS_CLASS_UTILITY 1
#endif

#ifdef PLATFORM_IS_APPLE
extern void *objc_autoreleasePoolPush();
extern void objc_autoreleasePoolPop(void *);
#endif

// Wakes are explicit, so this timeout is only a backstop against a missed
// wakeup; it is not how work gets discovered.
#define DEDICATED_PARK_TIMEOUT_US 1000000

// How long shutdown waits for dedicated threads to finish before giving up on
// them. A thread parked between messages leaves immediately; one that is inside
// a blocking syscall cannot be interrupted, which is the whole point of the
// feature, so past this point we leave its memory alone rather than free it out
// from under a running thread.
#define DEDICATED_STOP_TIMEOUT_US 2000000

// One warning, once, if an application creates far more dedicated actors than
// it can plausibly have meant to. Each one is a real OS thread.
#define DEDICATED_WARN_THRESHOLD 64

typedef struct dedicated_t
{
    pony_park_t park;

    PONY_ATOMIC(bool) terminate;

    // True from the moment work is handed to this thread until it is about to
    // park again. Read by ponyint_dedicated_is_idle() from other threads.
    PONY_ATOMIC(bool) busy;

    // Written by the owning thread (under list_mutex) the instant the actor
    // destroys itself, so that is_idle() can never follow a freed pointer.
    // Readers other than the owning thread must hold list_mutex.
    pony_actor_t* actor;

    struct dedicated_t* next;

    char name[16];
} dedicated_t;

static PONY_MUTEX list_mutex;
static dedicated_t* list_head;
static bool list_stopping;
static bool did_warn;

// Live dedicated actors.
static PONY_ATOMIC(int32_t) live_count;

// Dedicated threads that have not yet finished touching their own state.
// Shutdown waits on this rather than joining, because the threads are detached.
static PONY_ATOMIC(int32_t) thread_count;

static DECLARE_THREAD_FN(dedicated_thread_run);

void ponyint_dedicated_init(void)
{
    if(list_mutex == NULL) {
        list_mutex = ponyint_mutex_create();
    }

    ponyint_mutex_lock(list_mutex);
    list_stopping = false;
    ponyint_mutex_unlock(list_mutex);
}

int32_t ponyint_dedicated_count(void)
{
    return atomic_load_explicit(&live_count, memory_order_relaxed);
}

// Caller must hold list_mutex.
static void dedicated_unlink(dedicated_t* self)
{
    dedicated_t** link = &list_head;
    while(*link != NULL) {
        if(*link == self) {
            *link = self->next;
            self->next = NULL;
            return;
        }
        link = &(*link)->next;
    }
}

static void dedicated_free(dedicated_t* self)
{
    ponyint_park_destroy(&self->park);
    ponyint_pool_free(self, sizeof(dedicated_t));
}

pony_actor_t* ponyint_dedicated_create_actor(const char* name, int32_t coreAffinity)
{
    pony_actor_t* actor = ponyint_create_actor(pony_ctx());

    if(list_mutex == NULL) {
        // ponyint_dedicated_init() runs from pony_startup(), and an actor
        // cannot exist before that. Fail safe rather than run unsynchronised.
        pony_syslog2("Flynn", "dedicated actor created before startup; running on the shared schedulers");
        return actor;
    }

    dedicated_t* self = (dedicated_t*)ponyint_pool_alloc(sizeof(dedicated_t));
    memset(self, 0, sizeof(dedicated_t));

    self->actor = actor;
    ponyint_park_init(&self->park);
    atomic_store_explicit(&self->terminate, false, memory_order_relaxed);
    atomic_store_explicit(&self->busy, true, memory_order_relaxed);

    // pthread_setname_np() on linux wants 16 bytes including the terminator,
    // so there is no point carrying anything longer around.
    if(name != NULL) {
        strncpy(self->name, name, sizeof(self->name) - 1);
    } else {
        strncpy(self->name, "flynn-io", sizeof(self->name) - 1);
    }

    ponyint_actor_setcoreAffinity(actor, coreAffinity);

    // Publish before the thread exists: a message can arrive between here and
    // the thread starting, and the park absorbs that wake.
    actor->dedicated = self;

    int32_t count;
    bool warn = false;

    ponyint_mutex_lock(list_mutex);
    self->next = list_head;
    list_head = self;
    count = atomic_fetch_add_explicit(&live_count, 1, memory_order_relaxed) + 1;
    if(count > DEDICATED_WARN_THRESHOLD && did_warn == false) {
        did_warn = true;
        warn = true;
    }
    ponyint_mutex_unlock(list_mutex);

    if(warn) {
        pony_syslog2("Flynn",
                     "%d dedicated actors exist; each one owns an OS thread. Consider sharing "
                     "a smaller number of them instead", count);
    }

    // IO work is rarely latency critical and frequently blocked, so it belongs
    // on the efficiency side of the machine unless asked otherwise.
    int qos = QOS_CLASS_UTILITY;
    if(coreAffinity == kCoreAffinity_OnlyPerformance ||
       coreAffinity == kCoreAffinity_PreferPerformance) {
        qos = QOS_CLASS_USER_INITIATED;
    }

    atomic_fetch_add_explicit(&thread_count, 1, memory_order_relaxed);

    // The thread id lives here rather than in dedicated_t on purpose: the thread
    // frees its own dedicated_t when its actor is destroyed, which can happen
    // before this function reaches the detach below.
    pony_thread_id_t tid;

    if(ponyint_thread_create(&tid, dedicated_thread_run, qos, self) == false) {
        atomic_fetch_sub_explicit(&thread_count, 1, memory_order_relaxed);

        ponyint_mutex_lock(list_mutex);
        dedicated_unlink(self);
        atomic_fetch_sub_explicit(&live_count, 1, memory_order_relaxed);
        ponyint_mutex_unlock(list_mutex);

        // Fall back to a normally scheduled actor rather than an actor whose
        // messages nothing will ever run.
        actor->dedicated = NULL;
        dedicated_free(self);

        pony_syslog2("Flynn", "unable to create a dedicated thread; actor will run on the shared schedulers");
        return actor;
    }

    // Never joined. Shutdown waits on thread_count instead, so that a thread
    // stuck in a blocking call cannot wedge the whole process.
    ponyint_thread_detach(tid);

    return actor;
}

void ponyint_dedicated_wake(pony_actor_t* actor)
{
    dedicated_t* self = actor->dedicated;
    if(self == NULL) {
        return;
    }

    atomic_store_explicit(&self->busy, true, memory_order_release);
    ponyint_park_wake(&self->park);
}

bool ponyint_dedicated_is_idle(void)
{
    if(list_mutex == NULL) {
        return true;
    }

    bool idle = true;

    ponyint_mutex_lock(list_mutex);
    for(dedicated_t* d = list_head; d != NULL; d = d->next) {
        if(d->actor == NULL) {
            continue;
        }
        if(atomic_load_explicit(&d->busy, memory_order_acquire) ||
           ponyint_actor_num_messages(d->actor) > 0) {
            idle = false;
            break;
        }
    }
    ponyint_mutex_unlock(list_mutex);

    return idle;
}

void ponyint_dedicated_stop_all(void)
{
    if(list_mutex == NULL) {
        return;
    }

    ponyint_mutex_lock(list_mutex);
    list_stopping = true;
    for(dedicated_t* d = list_head; d != NULL; d = d->next) {
        atomic_store_explicit(&d->terminate, true, memory_order_release);
        ponyint_park_wake(&d->park);
    }
    ponyint_mutex_unlock(list_mutex);

    uint64_t waited_us = 0;
    while(atomic_load_explicit(&thread_count, memory_order_acquire) > 0) {
        if(waited_us >= DEDICATED_STOP_TIMEOUT_US) {
            pony_syslog2("Flynn",
                         "%d dedicated actor thread(s) still busy at shutdown; leaving them be",
                         atomic_load_explicit(&thread_count, memory_order_relaxed));
            return;
        }
        ponyint_cpu_sleep(1000);
        waited_us += 1000;
    }

    ponyint_mutex_lock(list_mutex);
    while(list_head != NULL) {
        dedicated_t* d = list_head;
        list_head = d->next;

        // Anything still holding this actor would be sending into a runtime
        // that no longer exists, but leave no dangling pointer behind.
        if(d->actor != NULL) {
            d->actor->dedicated = NULL;
        }
        dedicated_free(d);
    }
    list_stopping = false;
    ponyint_mutex_unlock(list_mutex);
}

static DECLARE_THREAD_FN(dedicated_thread_run)
{
    dedicated_t* self = (dedicated_t*)arg;
    pony_actor_t* actor = self->actor;

    // Not a scheduler: pony_ctx() hands back a placeholder whose ->scheduler is
    // NULL, so actors this thread sends to land on the inject queue, exactly
    // like sends from the timer loop or the main thread.
    pony_ctx_t* ctx = pony_ctx();

    ponyint_thead_setname_actual(self->name);
    ponyint_cpu_apply_thread_affinity(ponyint_actor_coreaffinity(actor));

#ifdef PLATFORM_IS_APPLE
    void* autorelease_pool = objc_autoreleasePoolPush();
#endif

    while(true) {
        int result = ponyint_actor_run(ctx, actor, actor->batchSize, NULL);

#ifdef PLATFORM_IS_APPLE
        objc_autoreleasePoolPop(autorelease_pool);
        autorelease_pool = objc_autoreleasePoolPush();
#endif

        if(result < 0) {
            // The actor destroyed itself inside ponyint_actor_run and `actor`
            // is now freed. Publish that before anything else, then leave.
            ponyint_mutex_lock(list_mutex);
            self->actor = NULL;
            ponyint_mutex_unlock(list_mutex);
            break;
        }

        if(result > 0) {
            // Messages remain, or a suspend/resume raced us. Keep going.
            continue;
        }

        // result == 0: ponyint_messageq_markempty() succeeded, so we are
        // unscheduled and the next sender is the one that reschedules us --
        // which for a dedicated actor means ponyint_dedicated_wake(). The
        // park's `signalled` flag closes the gap between here and the wait.
        atomic_store_explicit(&self->busy, false, memory_order_release);

        if(atomic_load_explicit(&self->terminate, memory_order_acquire)) {
            break;
        }

        ponyint_park_wait(&self->park, DEDICATED_PARK_TIMEOUT_US);

        atomic_store_explicit(&self->busy, true, memory_order_release);
    }

#ifdef PLATFORM_IS_APPLE
    objc_autoreleasePoolPop(autorelease_pool);
#endif

    // If a shutdown is in progress then ponyint_dedicated_stop_all() owns the
    // list and will free this entry once every thread has reported in; taking
    // ourselves out from under it would race its walk.
    bool stopping;

    ponyint_mutex_lock(list_mutex);
    stopping = list_stopping;
    if(stopping == false) {
        dedicated_unlink(self);
    }
    ponyint_mutex_unlock(list_mutex);

    if(stopping == false) {
        dedicated_free(self);
    }

    atomic_fetch_sub_explicit(&live_count, 1, memory_order_relaxed);

    // Releases the placeholder scheduler_t pony_ctx() allocated for us and
    // returns this thread's pool memory. Nothing below may touch pony state.
    pony_unregister_thread();

    atomic_fetch_sub_explicit(&thread_count, 1, memory_order_release);

    return 0;
}
