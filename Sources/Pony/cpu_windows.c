
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#define _GNU_SOURCE

#include "ponyrt.h"

#ifdef PLATFORM_IS_WINDOWS

#include "cpu.h"
#include "memory.h"

static uint32_t hw_core_count;
static uint32_t hybrid_cpu_enabled = 0;

static uint32_t hw_e_core_count = 0;
static uint32_t hw_p_core_count = 0;

void usleep(__int64 usec) 
{ 
    HANDLE timer; 
    LARGE_INTEGER ft; 

    ft.QuadPart = -(10*usec); // Convert to 100 nanosecond interval, negative value indicates relative time

    timer = CreateWaitableTimer(NULL, TRUE, NULL); 
    SetWaitableTimer(timer, &ft, 0, NULL, NULL, 0); 
    WaitForSingleObject(timer, INFINITE); 
    CloseHandle(timer); 
}

void ponyint_cpu_init()
{
    hw_core_count = 12;
    hw_e_core_count = 2;
    hw_p_core_count = 10;
    hybrid_cpu_enabled = 1;
}

uint32_t ponyint_p_core_count()
{
    return hw_p_core_count;
}

uint32_t ponyint_e_core_count()
{
    return hw_e_core_count;
}

uint32_t ponyint_core_count()
{
    return hw_core_count;
}

uint32_t ponyint_hybrid_cores_enabled()
{
    return hybrid_cpu_enabled;
}

void ponyint_cpu_sleep(int ns)
{
    usleep(ns);
}

void ponyint_cpu_relax()
{
    //asm volatile("pause" ::: "memory");
    usleep(1);
} 

uint64_t ponyint_cpu_tick()
{
    // TODO: linux
    return 0;
}

#endif
