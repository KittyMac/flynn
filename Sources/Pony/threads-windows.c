// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#ifdef PLATFORM_IS_WINDOWS

#define _GNU_SOURCE

#include "threads.h"
#include "ponyrt.h"

void ponyint_park_init(pony_park_t* park) {
    InitializeCriticalSection(&park->mutex);
    InitializeConditionVariable(&park->cond);
    park->signalled = false;
}

void ponyint_park_destroy(pony_park_t* park) {
    DeleteCriticalSection(&park->mutex);
}

void ponyint_park_wait(pony_park_t* park, uint64_t timeout_us) {
    EnterCriticalSection(&park->mutex);

    // If a wake landed while we were deciding to park, consume it and return
    // without sleeping. This is the case the lock exists to close.
    if (park->signalled == false) {
        // Round up: a sub-millisecond timeout must not truncate to zero, which
        // SleepConditionVariableCS treats as "do not wait at all".
        DWORD ms = (DWORD)((timeout_us + 999) / 1000);
        if (ms == 0) {
            ms = 1;
        }
        SleepConditionVariableCS(&park->cond, &park->mutex, ms);
    }

    // Spurious wakeups need no loop here: the caller's response to waking is to
    // go re-poll the queues, which is exactly the right thing to do anyway.
    park->signalled = false;
    LeaveCriticalSection(&park->mutex);
}

void ponyint_park_wake(pony_park_t* park) {
    EnterCriticalSection(&park->mutex);
    park->signalled = true;
    // Only ever one waiter per park, so wake rather than wake-all.
    WakeConditionVariable(&park->cond);
    LeaveCriticalSection(&park->mutex);
}

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
    uintptr_t p = _beginthreadex(NULL, 8 * 1024 * 1024, start, arg, 0, NULL);
    if (!p) {
        return false;
    }
    *thread = (HANDLE)p;
    return true;
}

bool ponyint_thread_join(pony_thread_id_t thread) {
    while (WaitForSingleObjectEx(thread, INFINITE, true) == WAIT_IO_COMPLETION);
    CloseHandle(thread);
    return true;
}

void ponyint_thread_detach(pony_thread_id_t thread) {
    
}

pony_thread_id_t ponyint_thread_self() {
    return GetCurrentThread();
}

void ponyint_thead_setname_actual(const char * thread_name) {
    
}

void ponyint_thead_setname(int schedID, int schedAffinity) {
    
}


#endif
