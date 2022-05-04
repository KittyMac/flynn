// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#include "ponyrt.h"
#include "threads.h"

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
//
// Almost all allocations are either 32 or 16 bytes, so if its < 32 bytes we just
// reuse 32 byte blocks

#define kMaxBlockSize 32
#define kMaxFreeBlocks 512

static size_t total_memory_allocated = 0;
static size_t max_memory_allocated = 0;
static PONY_ATOMIC(int64_t) unsafe_pony_mapped_memory = 0;

typedef struct pool_item_t {
    struct pool_item_t* next;
} pool_item_t;

typedef struct pool_local_t {
    pool_item_t* pool;
    size_t length;
    char* start;
    char* end;
} pool_local_t;

static __pony_thread_local pool_local_t pool_local[1] = {0};

static void* pool_get(pool_local_t* pool)
{
    pool_item_t* p = pool_local->pool;
    if(p != NULL) {
        pool_local->pool = p->next;
        pool_local->length--;
        return p;
    }
    return NULL;
}






void * ponyint_pool_alloc(size_t size) {
    if (size < kMaxBlockSize) {
        size = kMaxBlockSize;
    }
    if (size == kMaxBlockSize) {
        void * p = pool_get(pool_local);
        if (p != NULL) {
            return p;
        }
    }
    
    atomic_fetch_add_explicit(&unsafe_pony_mapped_memory, size, memory_order_relaxed);
    
    return malloc(size);
}

void ponyint_pool_free(void * p, size_t size) {
    if (size < kMaxBlockSize) {
        size = kMaxBlockSize;
    }
    if (size == kMaxBlockSize && pool_local->length < kMaxFreeBlocks) {
        pool_item_t* lp = (pool_item_t*)p;
        lp->next = pool_local->pool;
        pool_local->pool = lp;
        pool_local->length++;
        return;
    }
    
    atomic_fetch_sub_explicit(&unsafe_pony_mapped_memory, size, memory_order_relaxed);
    
    // For debug purposes, null out the memory before we free it
    //memset(p, 0x55, size);
    free(p);
}

pony_msg_t* pony_alloc_msg(size_t size, uint32_t msgId) {
    pony_msg_t* msg = (pony_msg_t*)ponyint_pool_alloc(size);
    msg->alloc_size = size;
    msg->msgId = msgId;
    return msg;
}

void ponyint_pool_thread_cleanup() {
    while (pool_local->length > 0) {
        void * p = ponyint_pool_alloc(kMaxBlockSize);
        if (p != NULL) {
            atomic_fetch_sub_explicit(&unsafe_pony_mapped_memory, kMaxBlockSize, memory_order_relaxed);
            free(p);
        }
    }
}

void ponyint_update_memory_usage() {
    struct rusage usage;
    if(0 == getrusage(RUSAGE_SELF, &usage)) {
#ifdef PLATFORM_IS_APPLE
        total_memory_allocated = usage.ru_maxrss; // bytes
#else
        total_memory_allocated = usage.ru_maxrss * 1024; // on linux, this is in kilobytes
#endif
    } else {
        total_memory_allocated = 0;
    }
    if(total_memory_allocated > max_memory_allocated) {
        max_memory_allocated = total_memory_allocated;
    }
}

size_t ponyint_total_memory()
{
    return total_memory_allocated;
}

size_t ponyint_max_memory()
{
    return max_memory_allocated;
}

size_t ponyint_usafe_mapped_memory()
{
    return unsafe_pony_mapped_memory;
}
