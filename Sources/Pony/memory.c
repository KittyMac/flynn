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
size_t getPeakRSS();
size_t getCurrentRSS();

void ponyint_update_memory_usage() {
    // gate this so that we only do it once every second
    static struct timeval previous = {0};
    struct timeval now;
    
    gettimeofday(&now, NULL);

    if (now.tv_sec - previous.tv_sec >= 1) {
        total_memory_allocated = getCurrentRSS();
        max_memory_allocated = getPeakRSS();
    }
    previous = now;
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
    
    if (pool_index >= 0) {
        pool_local_t* pool = pool_local + pool_index;
        if (pool->length < 512) {
            pool_item_t* lp = (pool_item_t*)p;
            lp->next = pool->pool;
            pool->pool = lp;
            pool->length++;
            return true;
        }
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
        
    atomic_fetch_add_explicit(&unsafe_pony_mapped_memory, size, memory_order_relaxed);
    //pony_syslog2("Flynn", "+ %lu\n", (size_t)unsafe_pony_mapped_memory);
    return malloc(size);
}

void ponyint_pool_free(void * p, size_t size) {
    size = ponyint_alloc_size(size);
    
    if (pool_push(p, size)) {
        return;
    }
    
    atomic_fetch_sub_explicit(&unsafe_pony_mapped_memory, size, memory_order_relaxed);
#if DEBUG
    memset(p, 55, size);
#endif
    free(p);
    
    //pony_syslog2("Flynn", "- %lu\n", (size_t)unsafe_pony_mapped_memory);
}

pony_msg_t* pony_alloc_msg(size_t size, uint32_t msgId) {
    pony_msg_t* msg = (pony_msg_t*)ponyint_pool_alloc(size);
    msg->alloc_size = (uint32_t)size;
    msg->msgId = msgId;
    return msg;
}

void ponyint_pool_thread_cleanup() {
    int pool_sizes[] = {32, 128, 256, 512, 2048, 4096};
    
    for (int i = 0; i < 6; i++) {
        size_t pool_size = pool_sizes[i];
        pool_local_t* pool = pool_local + i;
        while (pool->length > 0) {
            void * p = pool_pop(pool_size);
            if (p != NULL) {
                atomic_fetch_sub_explicit(&unsafe_pony_mapped_memory, pool_size, memory_order_relaxed);
                free(p);
                //pony_syslog2("Flynn", "[%lu] after: %lu\n", pool_size, (size_t)unsafe_pony_mapped_memory);
            }
        }
    }
}

/*
 * Author:  David Robert Nadeau
 * Site:    http://NadeauSoftware.com/
 * License: Creative Commons Attribution 3.0 Unported License
 *          http://creativecommons.org/licenses/by/3.0/deed.en_US
 */

#if defined(_WIN32)
#include <windows.h>
#include <psapi.h>

#elif defined(__unix__) || defined(__unix) || defined(unix) || (defined(__APPLE__) && defined(__MACH__))
#include <unistd.h>
#include <sys/resource.h>

#if defined(__APPLE__) && defined(__MACH__)
#include <mach/mach.h>

#elif (defined(_AIX) || defined(__TOS__AIX__)) || (defined(__sun__) || defined(__sun) || defined(sun) && (defined(__SVR4) || defined(__svr4__)))
#include <fcntl.h>
#include <procfs.h>

#elif defined(__linux__) || defined(__linux) || defined(linux) || defined(__gnu_linux__)
#include <stdio.h>

#endif

#else
#error "Cannot define getPeakRSS( ) or getCurrentRSS( ) for an unknown OS."
#endif





/**
 * Returns the peak (maximum so far) resident set size (physical
 * memory use) measured in bytes, or zero if the value cannot be
 * determined on this OS.
 */
size_t getPeakRSS( )
{
#if defined(_WIN32)
    /* Windows -------------------------------------------------- */
    PROCESS_MEMORY_COUNTERS info;
    GetProcessMemoryInfo( GetCurrentProcess( ), &info, sizeof(info) );
    return (size_t)info.PeakWorkingSetSize;

#elif (defined(_AIX) || defined(__TOS__AIX__)) || (defined(__sun__) || defined(__sun) || defined(sun) && (defined(__SVR4) || defined(__svr4__)))
    /* AIX and Solaris ------------------------------------------ */
    struct psinfo psinfo;
    int fd = -1;
    if ( (fd = open( "/proc/self/psinfo", O_RDONLY )) == -1 )
        return (size_t)0L;      /* Can't open? */
    if ( read( fd, &psinfo, sizeof(psinfo) ) != sizeof(psinfo) )
    {
        close( fd );
        return (size_t)0L;      /* Can't read? */
    }
    close( fd );
    return (size_t)(psinfo.pr_rssize * 1024L);

#elif defined(__unix__) || defined(__unix) || defined(unix) || (defined(__APPLE__) && defined(__MACH__))
    /* BSD, Linux, and OSX -------------------------------------- */
    struct rusage rusage;
    getrusage( RUSAGE_SELF, &rusage );
#if defined(__APPLE__) && defined(__MACH__)
    return (size_t)rusage.ru_maxrss;
#else
    return (size_t)(rusage.ru_maxrss * 1024L);
#endif

#else
    /* Unknown OS ----------------------------------------------- */
    return (size_t)0L;          /* Unsupported. */
#endif
}





/**
 * Returns the current resident set size (physical memory use) measured
 * in bytes, or zero if the value cannot be determined on this OS.
 */
size_t getCurrentRSS( )
{
#if defined(_WIN32)
    /* Windows -------------------------------------------------- */
    PROCESS_MEMORY_COUNTERS info;
    GetProcessMemoryInfo( GetCurrentProcess( ), &info, sizeof(info) );
    return (size_t)info.WorkingSetSize;

#elif defined(__APPLE__) && defined(__MACH__)
    /* OSX ------------------------------------------------------ */
    struct task_vm_info info;
    mach_msg_type_number_t infoCount = TASK_VM_INFO_COUNT;
    if ( task_info( mach_task_self( ), TASK_VM_INFO,
        (task_info_t)&info, &infoCount ) != KERN_SUCCESS )
        return (size_t)0L;      /* Can't access? */
    return (size_t)info.phys_footprint;

#elif defined(__linux__) || defined(__linux) || defined(linux) || defined(__gnu_linux__)
    /* Linux ---------------------------------------------------- */
    long rss = 0L;
    FILE* fp = NULL;
    if ( (fp = fopen( "/proc/self/statm", "r" )) == NULL )
        return (size_t)0L;      /* Can't open? */
    if ( fscanf( fp, "%*s%ld", &rss ) != 1 )
    {
        fclose( fp );
        return (size_t)0L;      /* Can't read? */
    }
    fclose( fp );
    return (size_t)rss * (size_t)sysconf( _SC_PAGESIZE);

#else
    /* AIX, BSD, Solaris, and Unknown OS ------------------------ */
    return (size_t)0L;          /* Unsupported. */
#endif
}
