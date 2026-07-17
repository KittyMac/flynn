// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#ifndef PLATFORM_IS_WINDOWS

#define _GNU_SOURCE

#include "threads.h"
#include "ponyrt.h"

#include <pthread.h>
#include <sched.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <sys/mman.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#ifdef PLATFORM_IS_APPLE
#undef id
#include <Foundation/Foundation.h>
#endif

PONY_MUTEX ponyint_mutex_create() {
    pthread_mutex_t * mutex = malloc(sizeof(pthread_mutex_t));
    if (pthread_mutex_init(mutex, NULL) != 0) {
        free(mutex);
        return NULL;
    }
    return mutex;
}

void ponyint_mutex_destroy(PONY_MUTEX mutex) {
    if (mutex != NULL) {
        pthread_mutex_destroy(mutex);
    }
}

void ponyint_mutex_lock(PONY_MUTEX mutex) {
    if (mutex != NULL) {
        pthread_mutex_lock(mutex);
    }
}

void ponyint_mutex_unlock(PONY_MUTEX mutex) {
    if (mutex != NULL) {
        pthread_mutex_unlock(mutex);
    }
}

bool ponyint_thread_create(pony_thread_id_t* thread, thread_fn start, int qos, void* arg)
{
    bool ret = true;

    pthread_attr_t attr;
    pthread_attr_init(&attr);

    // Start from RLIMIT_STACK's soft limit when it is sane...
    size_t desired = 0;
    struct rlimit limit;
    if (getrlimit(RLIMIT_STACK, &limit) == 0 &&
        limit.rlim_cur != RLIM_INFINITY &&
        limit.rlim_cur >= (rlim_t)PTHREAD_STACK_MIN) {
        desired = (size_t)limit.rlim_cur;
    }

    // ...but never below our floor
    size_t floor = (8 * 1024 * 1024);
    if (desired < floor) {
        desired = floor;
    }

    // pthread_attr_setstacksize requires a value that is >= PTHREAD_STACK_MIN
    // AND a multiple of the page size (16 KB on Apple Silicon, not 4 KB),
    // else it returns EINVAL and the attr silently keeps its small default.
    long page = sysconf(_SC_PAGESIZE);
    if (page <= 0) page = 4096;
    if (desired < (size_t)PTHREAD_STACK_MIN)
        desired = (size_t)PTHREAD_STACK_MIN;
    desired -= (desired % (size_t)page);
    if (desired < (size_t)PTHREAD_STACK_MIN)
        desired += (size_t)page;

    int rc = pthread_attr_setstacksize(&attr, desired);
    if (rc != 0) {
        fprintf(stderr,
            "flynn: pthread_attr_setstacksize(%zu) failed (rc=%d); "
            "scheduler thread will use the default stack size\n", desired, rc);
    }

#ifdef PLATFORM_IS_APPLE
    pthread_attr_set_qos_class_np(&attr, qos, 0);
#endif

    if (pthread_create(thread, &attr, start, arg))
        ret = false;
    pthread_attr_destroy(&attr);
    return ret;
}

bool ponyint_thread_join(pony_thread_id_t thread)
{
    if (pthread_join(thread, NULL))
        return false;
    return true;
}

void ponyint_thread_detach(pony_thread_id_t thread)
{
    pthread_detach(thread);
}

pony_thread_id_t ponyint_thread_self()
{
    return pthread_self();
}

void ponyint_thead_setname_actual(const char * thread_name) {
#ifdef PLATFORM_IS_APPLE
    [[NSThread currentThread] setName:[NSString stringWithUTF8String:thread_name]];
    pthread_setname_np(thread_name);
#endif
    
#ifdef PLATFORM_IS_LINUX
    pthread_setname_np(pthread_self(), thread_name);
#endif
    
    signal(SIGPIPE, SIG_IGN);
}

void ponyint_thead_setname(int schedID, int schedAffinity) {
    char thread_name[128] = {0};
    char * thread_affinity = "";
    switch (schedAffinity) {
        case kCoreAffinity_OnlyEfficiency:
            thread_affinity = "(E)";
            break;
        case kCoreAffinity_OnlyPerformance:
            thread_affinity = "(P)";
            break;
    }
    snprintf(thread_name, sizeof(thread_name), "Flynn #%d %s", schedID, thread_affinity);
    
    ponyint_thead_setname_actual(thread_name);
}

#endif
