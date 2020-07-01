// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"
#ifdef PLATFORM_SUPPORTS_PONYRT

#ifndef PLATFORM_THREADS_H
#define PLATFORM_THREADS_H

#include <stdbool.h>

/** Multithreading support.
 *
 */
#include <pthread.h>
#include <signal.h>


#define kCoreAffinity_PreferEfficiency 0
#define kCoreAffinity_PreferPerformance 1
#define kCoreAffinity_OnlyEfficiency 2
#define kCoreAffinity_OnlyPerformance 3

#define kCoreAffinity_OnlyThreshold 2


#define pony_thread_id_t pthread_t
#define pony_signal_event_t pthread_cond_t*

typedef void* (*thread_fn) (void* arg);

#define DECLARE_THREAD_FN(NAME) void* NAME (void* arg)

#define __pony_thread_local __thread

bool ponyint_thread_create(pony_thread_id_t* thread, thread_fn start, int qos, void* arg);

bool ponyint_thread_join(pony_thread_id_t thread);

void ponyint_thread_detach(pony_thread_id_t thread);

pony_thread_id_t ponyint_thread_self(void);

void ponyint_thead_setname(int schedID, int schedAffinity);

#endif

#endif
