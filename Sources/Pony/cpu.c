//
//  cpu.h
//  Flynn
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include <unistd.h>

#include "cpu.h"
#include "pool.h"

#ifdef PLATFORM_IS_APPLE
#undef id
#include <mach/mach.h>
#include <mach/thread_policy.h>
#include <mach/mach_time.h>
#endif

#include <sys/types.h>
#include <sys/sysctl.h>
#include <errno.h>
#include <string.h>

#ifndef CPUFAMILY_ARM_MONSOON_MISTRAL
	#define CPUFAMILY_ARM_MONSOON_MISTRAL   0xE81E7EF6
#endif
#ifndef CPUFAMILY_ARM_VORTEX_TEMPEST
	#define CPUFAMILY_ARM_VORTEX_TEMPEST    0x07D34B9F
#endif
#ifndef CPUFAMILY_ARM_LIGHTNING_THUNDER
	#define CPUFAMILY_ARM_LIGHTNING_THUNDER 0x462504D2
#endif

#ifndef CTL_HW
	#define CTL_HW 6 
#endif

#ifdef PLATFORM_IS_APPLE
static uint32_t get_sys_info(int type_specifier, const char* name, uint32_t default_value) {
    size_t size = 0;
    uint32_t result = default_value;
    int mib[2] = { CTL_HW, type_specifier };
    if (sysctl(mib, 2, NULL, &size, NULL, 0) != 0) {
        fprintf(stderr, "sysctl(\"%s\") failed: %s\n", name, strerror(errno));
    } else if (size == sizeof(uint32_t)) {
        sysctl(mib, 2, &result, &size, NULL, 0);
        //fprintf(stderr, "%s: %u, size = %lu\n", name, result, size);
    } else {
        fprintf(stderr, "sysctl does not support non-integer lookup for (\"%s\")\n", name);
    }
    return result;
}

static uint32_t get_sys_info_by_name(const char* type_specifier, uint32_t default_value) {
    size_t size = 0;
    uint32_t result = default_value;
    if (sysctlbyname(type_specifier, NULL, &size, NULL, 0) != 0) {
        fprintf(stderr, "sysctlbyname(\"%s\") failed: %s\n", type_specifier, strerror(errno));
    } else if (size == sizeof(uint32_t)) {
        sysctlbyname(type_specifier, &result, &size, NULL, 0);
        //fprintf(stderr, "%s: %u, size = %lu\n", type_specifier, result, size);
    } else {
        fprintf(stderr, "sysctl does not support non-integer lookup for (\"%s\")\n", type_specifier);
    }
    return result;
}
#endif

static uint32_t hw_core_count;
static uint32_t hw_cpu_count;

static uint32_t hw_e_core_count = 0;
static uint32_t hw_p_core_count = 0;

void ponyint_cpu_init()
{
#ifdef PLATFORM_IS_LINUX
    unsigned int eax=11,ebx=0,ecx=1,edx=0;

    asm volatile("cpuid"
            : "=a" (eax),
              "=b" (ebx),
              "=c" (ecx),
              "=d" (edx)
            : "0" (eax), "2" (ecx)
            : );

    printf("Cores: %d\nThreads: %d\nActual thread: %d\n",eax,ebx,edx);
#endif
    
#ifdef PLATFORM_IS_APPLE
    hw_core_count = get_sys_info_by_name("hw.physicalcpu", 1);
    hw_cpu_count = hw_core_count / get_sys_info_by_name("machdep.cpu.core_count", 1);
    
    const uint32_t cpu_family = get_sys_info_by_name("hw.cpufamily", 0);
    switch (cpu_family) {
        case CPUFAMILY_ARM_MONSOON_MISTRAL:
            /* 2x Monsoon + 4x Mistral cores */
            hw_e_core_count = 4;
            hw_p_core_count = 2;
        case CPUFAMILY_ARM_VORTEX_TEMPEST:
        case CPUFAMILY_ARM_LIGHTNING_THUNDER:
            /* Hexa-core: 2x Vortex + 4x Tempest; Octa-core: 4x Cortex + 4x Tempest */
            /* Hexa-core: 2x Lightning + 4x Thunder; Octa-core (presumed): 4x Lightning + 4x Thunder */
            if (hw_core_count == 6) {
                hw_e_core_count = 4;
                hw_p_core_count = 2;
            }
            if (hw_core_count == 8) {
                hw_e_core_count = 4;
                hw_p_core_count = 4;
            }
            break;
    }
    
    if (hw_e_core_count == 0 || hw_p_core_count == 0) {
        hw_e_core_count = hw_core_count / 2;
        hw_p_core_count = hw_core_count - hw_e_core_count;
    }
#endif
    
    if (hw_e_core_count == 0) {
        hw_e_core_count = 1;
    }
    if (hw_p_core_count == 0) {
        hw_p_core_count = 1;
    }
    
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

uint32_t ponyint_cpu_count()
{
    return hw_cpu_count;
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
#ifdef PLATFORM_IS_APPLE
    static mach_timebase_info_data_t info;
    static bool mach_timebase_init = false;
    
    if (mach_timebase_init == false) {
        if (mach_timebase_info(&info) != KERN_SUCCESS) return (uint64_t)-1.0;
        mach_timebase_init = true;
    }
    
    return mach_absolute_time () * info.numer / info.denom;
#endif

#ifdef PLATFORM_IS_LINUX
	// TODO: linux
    return 0;
#endif
}
