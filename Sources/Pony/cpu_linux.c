//
//  cpu.h
//  Flynn
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"
#ifdef PLATFORM_SUPPORTS_PONYRT

#define _GNU_SOURCE

#include "ponyrt.h"

#ifdef PLATFORM_IS_LINUX

#include <unistd.h>

#include "cpu.h"
#include "pool.h"

#include <sched.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>

static uint32_t avail_cpu_count;
static uint32_t* avail_cpu_list;
static uint32_t avail_cpu_size;

static uint32_t hw_core_count;
static uint32_t hw_cpu_count;

static uint32_t hw_e_core_count = 0;
static uint32_t hw_p_core_count = 0;



static bool cpu_physical(uint32_t cpu)
{
    char file[FILENAME_MAX];
    snprintf(file, FILENAME_MAX,
             "/sys/devices/system/cpu/cpu%d/topology/thread_siblings_list", cpu);
    
    FILE* fp = fopen(file, "r");
    
    if(fp != NULL)
    {
        char name[16];
        size_t len = fread(name, 1, 15, fp);
        name[len] = '\0';
        fclose(fp);
        
        if(cpu != (uint32_t)atoi(name))
            return false;
    }
    
    return true;
}

static uint32_t cpu_add_mask_to_list(uint32_t i, cpu_set_t* mask)
{
    uint32_t count = CPU_COUNT(mask);
    uint32_t index = 0;
    uint32_t found = 0;
    
    while(found < count)
    {
        if(CPU_ISSET(index, mask))
        {
            avail_cpu_list[i++] = index;
            found++;
        }
        
        index++;
    }
    
    return i;
}


void ponyint_cpu_init()
{
    cpu_set_t all_cpus;
    cpu_set_t hw_cpus;
    cpu_set_t ht_cpus;
    
    sched_getaffinity(0, sizeof(cpu_set_t), &all_cpus);
    CPU_ZERO(&hw_cpus);
    CPU_ZERO(&ht_cpus);
    
    avail_cpu_size = avail_cpu_count = CPU_COUNT(&all_cpus);
    uint32_t index = 0;
    uint32_t found = 0;
    
    while(found < avail_cpu_count)
    {
        if(CPU_ISSET(index, &all_cpus))
        {
            if(cpu_physical(index))
                CPU_SET(index, &hw_cpus);
            else
                CPU_SET(index, &ht_cpus);
            
            found++;
        }
        
        index++;
    }
    
    hw_cpu_count = CPU_COUNT(&hw_cpus);
    
    if (hw_e_core_count == 0 || hw_p_core_count == 0) {
        hw_e_core_count = hw_core_count / 2;
        hw_p_core_count = hw_core_count - hw_e_core_count;
    }
        
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
    // TODO: linux
    return 0;
}

#endif

#endif
