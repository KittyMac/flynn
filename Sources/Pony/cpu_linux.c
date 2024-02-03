
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#define _GNU_SOURCE

#include "ponyrt.h"

#ifdef PLATFORM_IS_LINUX

#include <unistd.h>

#include "cpu.h"
#include "memory.h"

#include <sched.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>

static uint32_t avail_cpu_count;

static uint32_t hw_core_count;
static uint32_t hybrid_cpu_enabled = 0;

static uint32_t hw_e_core_count = 0;
static uint32_t hw_p_core_count = 0;

void ponyint_cpu_init()
{
    cpu_set_t all_cpus;

    sched_getaffinity(0, sizeof(cpu_set_t), &all_cpus);
    avail_cpu_count = CPU_COUNT(&all_cpus);
    
    hw_core_count = avail_cpu_count;
    if (hw_core_count < 2) {
        hw_core_count = 2;
    }
    
    hw_e_core_count = 1;
    hw_p_core_count = hw_core_count - hw_e_core_count;
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
