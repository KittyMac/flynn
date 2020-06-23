// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "ponyrt.h"
#include "threads.h"
#include <pthread.h>
#include <sched.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <sys/mman.h>
#include <limits.h>

bool ponyint_thread_create(pony_thread_id_t* thread, thread_fn start, int schedID, int qos, void* arg)
{
    bool ret = true;
    
    bool setstack_called = false;
    struct rlimit limit;
    pthread_attr_t attr;
    pthread_attr_t* attr_p = &attr;
    pthread_attr_init(attr_p);
    
    // Some systems, e.g., macOS, hav a different default default
    // stack size than the typical system's RLIMIT_STACK.
    // Let's use RLIMIT_STACK's current limit if it is sane.
    if(getrlimit(RLIMIT_STACK, &limit) == 0 &&
       limit.rlim_cur != RLIM_INFINITY &&
       limit.rlim_cur >= PTHREAD_STACK_MIN)
    {
        if(! setstack_called)
            pthread_attr_setstacksize(&attr, (size_t)limit.rlim_cur);
    } else {
        attr_p = NULL;
    }
    
    pthread_attr_set_qos_class_np(&attr, qos, 0);
    
    
    char thread_name[128] = {0};
    snprintf(thread_name, sizeof(thread_name), "Flynn #%d, QoS %d", schedID, qos);
    pthread_setname_np(thread_name);
    
    if(pthread_create(thread, attr_p, start, arg))
        ret = false;
    pthread_attr_destroy(&attr);
    return ret;
}

bool ponyint_thread_join(pony_thread_id_t thread)
{
    if(pthread_join(thread, NULL))
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
