// Note: This code is derivative of the Pony runtime; see README.md for more details

#ifndef PLATFORM_THREADS_H
#define PLATFORM_THREADS_H

#include <stdbool.h>

/** Multithreading support.
 *
 */
#include <pthread.h>
#include <signal.h>
#define pony_thread_id_t pthread_t
#define pony_signal_event_t pthread_cond_t*

typedef void* (*thread_fn) (void* arg);

#define DECLARE_THREAD_FN(NAME) void* NAME (void* arg)

#define __pony_thread_local __thread

bool ponyint_thread_create(pony_thread_id_t* thread, thread_fn start, int schedID, int qos, void* arg);

bool ponyint_thread_join(pony_thread_id_t thread);

void ponyint_thread_detach(pony_thread_id_t thread);

pony_thread_id_t ponyint_thread_self(void);

#endif
