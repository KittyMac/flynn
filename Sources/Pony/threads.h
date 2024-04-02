// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#ifndef PLATFORM_THREADS_H
#define PLATFORM_THREADS_H

#include <stdbool.h>

#ifdef PLATFORM_IS_WINDOWS

    #include <windows.h>
    #include <process.h>

    typedef HANDLE PONY_MUTEX;

    #define pony_thread_id_t HANDLE
    #define pony_signal_event_t HANDLE

    typedef unsigned int (*thread_fn) (void* arg);

    #define DECLARE_THREAD_FN(NAME) unsigned int NAME (void* arg)
    
    #define __pony_thread_local __thread

#else

    #include <pthread.h>
    #include <signal.h>

    typedef pthread_mutex_t* PONY_MUTEX;
    
    #define pony_thread_id_t pthread_t
    #define pony_signal_event_t pthread_cond_t*

    typedef void* (*thread_fn) (void* arg);

    #define DECLARE_THREAD_FN(NAME) void* NAME (void* arg)
    
    #define __pony_thread_local __thread
    
#endif


#define kCoreAffinity_PreferEfficiency 0
#define kCoreAffinity_PreferPerformance 1
#define kCoreAffinity_OnlyEfficiency 2
#define kCoreAffinity_OnlyPerformance 3

#define COREAFFINITY_IS_INCOMPATIBLE(x, y) ((x == kCoreAffinity_OnlyEfficiency || x == kCoreAffinity_OnlyPerformance) && x != y)
#define COREAFFINITY_IS_PREFERENTIAL(x) (x <= kCoreAffinity_PreferPerformance)
#define COREAFFINITY_PREFER_TO_ONLY(x) (x + 2)

#define kCoreAffinity_None 99

PONY_MUTEX ponyint_mutex_create();
void ponyint_mutex_destroy(PONY_MUTEX mutex);
void ponyint_mutex_lock(PONY_MUTEX mutex);
void ponyint_mutex_unlock(PONY_MUTEX mutex);

bool ponyint_thread_create(pony_thread_id_t* thread, thread_fn start, int qos, void* arg);
bool ponyint_thread_join(pony_thread_id_t thread);
void ponyint_thread_detach(pony_thread_id_t thread);
pony_thread_id_t ponyint_thread_self(void);
void ponyint_thead_setname_actual(char * thread_name);
void ponyint_thead_setname(int schedID, int schedAffinity);

#endif
