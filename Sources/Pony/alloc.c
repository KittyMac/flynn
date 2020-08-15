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

static size_t total_memory_allocated = 0;
static size_t max_memory_allocated = 0;

void ponyint_update_memory_usage() {
    struct rusage usage;
    if(0 == getrusage(RUSAGE_SELF, &usage)) {
#ifdef PLATFORM_IS_APPLE
        total_memory_allocated = usage.ru_maxrss; // bytes
#else
        total_memory_allocated = usage.ru_maxrss / 1024; // on linux, this is in kilobytes
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

void* ponyint_virt_alloc(size_t bytes)
{
    void* p;
    bool ok = true;
    
#ifdef PLATFORM_IS_APPLE
    p = mmap(0, bytes, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON | VM_FLAGS_SUPERPAGE_SIZE_ANY, -1, 0);
#else
    p = mmap(0, bytes, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
#endif
    
    if(p == MAP_FAILED)
        ok = false;
    
    if(!ok)
    {
        perror("out of memory: ");
        abort();
    }
    
    return p;
}

void ponyint_virt_free(void* p, size_t bytes)
{
    munmap(p, bytes);
}
