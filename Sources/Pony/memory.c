// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#include "ponyrt.h"

#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include <sys/mman.h>
#include <sys/time.h>
#include <sys/resource.h>

#ifdef PLATFORM_IS_APPLE
#include <mach/vm_statistics.h>
#endif

// Goals:
// 1. reduce the number of calls to malloc()/free()
// 2. be able to release memory back to the OS
// 3. thread safe with no locks on the fast path

// Advantages:
// Pony's memory system had to account for EVERYTHING, however Flynn has a very
// narrow use case for memory (ie a lot of our repeated allocations will be the
// same size).

void * ponyint_pool_alloc(size_t size) {
    return malloc(size);
}

void * ponyint_pool_free(void * p, size_t size) {
    free(p);
}

pony_msg_t* pony_alloc_msg(size_t size, uint32_t msgId) {
    pony_msg_t* msg = (pony_msg_t*)ponyint_pool_alloc(size);
    msg->alloc_size = size;
    msg->msgId = msgId;
    return msg;
}

void ponyint_pool_thread_cleanup() {
    
}

void ponyint_update_memory_usage() {
    
}
