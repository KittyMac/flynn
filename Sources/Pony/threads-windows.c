// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#ifdef PLATFORM_WINDOWS

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

#ifdef PLATFORM_IS_APPLE
#undef id
#include <Foundation/Foundation.h>
#endif

bool ponyint_thread_create(pony_thread_id_t* thread, thread_fn start, int qos, void* arg)
{
    return NULL;
}

bool ponyint_thread_join(pony_thread_id_t thread)
{
    return false;
}

void ponyint_thread_detach(pony_thread_id_t thread)
{
    // pthread_detach(thread);
}

pony_thread_id_t ponyint_thread_self()
{
    return pthread_self();
}

void ponyint_thead_setname_actual(char * thread_name) {
    /*
#ifdef PLATFORM_IS_APPLE
    [[NSThread currentThread] setName:[NSString stringWithUTF8String:thread_name]];
    pthread_setname_np(thread_name);
#endif
    
#ifdef PLATFORM_IS_LINUX
    pthread_setname_np(pthread_self(), thread_name);
#endif
    
    signal(SIGPIPE, SIG_IGN);
     */
}

void ponyint_thead_setname(int schedID, int schedAffinity) {
    
    /*
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
     */
}


#endif
