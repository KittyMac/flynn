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


// ******** Memory statistics ********

static size_t total_memory_allocated = 0;
static size_t max_memory_allocated = 0;
static PONY_ATOMIC(int64_t) unsafe_pony_mapped_memory = 0;

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


// ******** Thread-local reusable memory allocation pools ********

typedef struct pool_item_t {
    struct pool_item_t* next;
} pool_item_t;

typedef struct pool_local_t {
    pool_item_t* pool;
    size_t length;
    char* start;
    char* end;
} pool_local_t;

static __pony_thread_local pool_local_t pool_local[6] = {0};

static int32_t ponyint_pool_index(size_t size) {
    if (size <= 32) { return 0; }
    if (size <= 128) { return 1; }
    if (size <= 256) { return 2; }
    if (size <= 512) { return 3; }
    if (size <= 2048) { return 4; }
    if (size <= 4096) { return 5; }
    return -1;
}

static size_t ponyint_alloc_size(size_t size) {
    if (size <= 32) { return 32; }
    if (size <= 128) { return 128; }
    if (size <= 256) { return 256; }
    if (size <= 512) { return 512; }
    if (size <= 2048) { return 2048; }
    if (size <= 4096) { return 4096; }
    return size;
}

static void* pool_pop(size_t size) {
    int32_t pool_index = ponyint_pool_index(size);
    if (pool_index < 0) {
        return NULL;
    }
    
    pool_local_t* pool = pool_local + pool_index;
    pool_item_t* p = pool->pool;
    if(p != NULL) {
        pool->pool = p->next;
        pool->length--;
        return p;
    }
    return NULL;
}

static bool pool_push(void * p, size_t size) {
    int32_t pool_index = ponyint_pool_index(size);
    if (pool_index >= 0 && pool_local->length < 512) {
        pool_item_t* lp = (pool_item_t*)p;
        lp->next = pool_local->pool;
        pool_local->pool = lp;
        pool_local->length++;
        return true;
    }
    return false;
}




// ******** Exposed API ********

void * ponyint_pool_alloc(size_t size) {
    size = ponyint_alloc_size(size);
    
    void * p = pool_pop(size);
    if (p != NULL) {
        return p;
    }
    
    //fprintf(stderr, "alloc: %lu\n", size);
    
    atomic_fetch_add_explicit(&unsafe_pony_mapped_memory, size, memory_order_relaxed);
    
    return malloc(size);
}

void ponyint_pool_free(void * p, size_t size) {
    if (pool_push(p, size)) {
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
    int pool_sizes[] = {32, 128, 256, 512, 2048, 4096};
    
    for (int i = 0; i < 6; i++) {
        size_t pool_size = pool_sizes[i];
        pool_local_t* pool = pool_local + i;
        while (pool->length > 0) {
            pool_pop(pool_size);
        }
    }
}

