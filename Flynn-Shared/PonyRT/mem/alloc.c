// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "ponyrt.h"

#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include <sys/mman.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <mach/vm_statistics.h>

static size_t total_memory_allocated = 0;
static bool has_requested_total_memory = false;

void ponyint_update_memory_usage() {
    // as getting the total OS memory usage is expensive, don't collect it
    // unless someone has asked for it before.
    if (has_requested_total_memory == false) {
        return;
    }
    struct rusage usage;
    if(0 == getrusage(RUSAGE_SELF, &usage)) {
        total_memory_allocated = usage.ru_maxrss; // bytes
    } else {
        total_memory_allocated = 0;
    }
}

size_t ponyint_total_memory()
{
    if (has_requested_total_memory == false) {
        has_requested_total_memory = true;
        ponyint_update_memory_usage();
    }
    
    return total_memory_allocated;
}

void* ponyint_virt_alloc(size_t bytes)
{
    void* p;
    bool ok = true;
    
    p = mmap(0, bytes, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON | VM_FLAGS_SUPERPAGE_SIZE_ANY, -1, 0);
    
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
