//
//  cpu.h
//  Flynn
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include <unistd.h>
#include <mach/mach.h>
#include <mach/thread_policy.h>
#include <mach/mach_time.h>

#include "cpu.h"
#include "pool.h"

#include <sys/types.h>
#include <sys/sysctl.h>

static uint32_t property(const char* key)
{
    int value;
    size_t len = sizeof(int);
    sysctlbyname(key, &value, &len, NULL, 0);
    return value;
}

static uint32_t hw_cpu_count;

void ponyint_cpu_init()
{
    hw_cpu_count = property("hw.physicalcpu");
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
    static mach_timebase_info_data_t info;
    static bool mach_timebase_init = false;
    
    if (mach_timebase_init == false) {
        if (mach_timebase_info(&info) != KERN_SUCCESS) return (uint64_t)-1.0;
        mach_timebase_init = true;
    }
    
    return mach_absolute_time () * info.numer / info.denom;
}
