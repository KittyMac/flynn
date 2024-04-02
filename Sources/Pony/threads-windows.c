// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#ifdef PLATFORM_IS_WINDOWS

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

PONY_MUTEX ponyint_mutex_create() {
    return CreateMutex(NULL, FALSE, NULL);
}

void ponyint_mutex_destroy(PONY_MUTEX mutex) {
    if (mutex != NULL) {
        CloseHandle(mutex);
    }
}

void ponyint_mutex_lock(PONY_MUTEX mutex) {
    WaitForSingleObject(mutex, INFINITE);
}

void ponyint_mutex_unlock(PONY_MUTEX mutex) {
    ReleaseMutex(mutex);
}

bool ponyint_thread_create(pony_thread_id_t* thread, thread_fn start, int qos, void* arg) {
    uintptr_t p = _beginthreadex(NULL, 0, start, arg, 0, NULL);
    if (!p) {
        return false;
    }
    *thread = (HANDLE)p;
    return true;
}

bool ponyint_thread_join(pony_thread_id_t thread) {
    while (WaitForSingleObjectEx(thread, INFINITE, true) == WAIT_IO_COMPLETION);
    CloseHandle(thread);
}

void ponyint_thread_detach(pony_thread_id_t thread) {
    
}

pony_thread_id_t ponyint_thread_self() {
    return GetCurrentThread();
}

void ponyint_thead_setname_actual(char * thread_name) {
    
}

void ponyint_thead_setname(int schedID, int schedAffinity) {
    
}


#endif
