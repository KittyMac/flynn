
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#include "ponyrt.h"

#ifdef PLATFORM_IS_APPLE

#include <unistd.h>

#include "cpu.h"
#include "memory.h"

#undef id
#include <mach/mach.h>
#include <mach/thread_policy.h>
#include <mach/mach_time.h>

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

void pony_usleep(uint64_t usec)
{
    usleep((useconds_t)usec);
}

static uint32_t get_sys_info(int type_specifier, const char* name, uint32_t default_value) {
    size_t size = 0;
    uint32_t result = default_value;
    int mib[2] = { CTL_HW, type_specifier };
    if (sysctl(mib, 2, NULL, &size, NULL, 0) != 0) {
        pony_syslog2("Flynn", "sysctl(\"%s\") failed: %s\n", name, strerror(errno));
    } else if (size == sizeof(uint32_t)) {
        sysctl(mib, 2, &result, &size, NULL, 0);
        //pony_syslog2("Flynn", "%s: %u, size = %lu\n", name, result, size);
    } else {
        pony_syslog2("Flynn", "sysctl does not support non-integer lookup for (\"%s\")\n", name);
    }
    return result;
}

static uint32_t get_sys_info_by_name(const char* type_specifier, uint32_t default_value) {
    size_t size = 0;
    uint32_t result = default_value;
    if (sysctlbyname(type_specifier, NULL, &size, NULL, 0) != 0) {
        pony_syslog2("Flynn", "sysctlbyname(\"%s\") failed: %s\n", type_specifier, strerror(errno));
    } else if (size == sizeof(uint32_t)) {
        sysctlbyname(type_specifier, &result, &size, NULL, 0);
        //pony_syslog2("Flynn", "%s: %u, size = %lu\n", type_specifier, result, size);
    } else {
        pony_syslog2("Flynn", "sysctl does not support non-integer lookup for (\"%s\")\n", type_specifier);
    }
    return result;
}

static uint32_t hybrid_cpu_enabled = 0;

static uint32_t hw_core_count = 0;

static uint32_t hw_e_core_count = 0;
static uint32_t hw_p_core_count = 0;

void ponyint_cpu_init()
{
    // hw.logicalcpu or hw.physicalcpu
    hw_core_count = get_sys_info_by_name("hw.logicalcpu", 1);
    if (hw_core_count == 0) {
        hw_core_count = get_sys_info_by_name("hw.physicalcpu", 1);
    }
    
    size_t size = sizeof(uint32_t);
    // Performance cores (big cores)
    if (sysctlbyname("hw.perflevel0.logicalcpu", &hw_p_core_count, &size, NULL, 0) == -1) {
        hw_p_core_count = 0;
    }
    
    // Efficiency cores (little cores)
    if (sysctlbyname("hw.perflevel1.logicalcpu", &hw_e_core_count, &size, NULL, 0) == -1) {
        hw_e_core_count = 0;
    }
    
    hybrid_cpu_enabled = 1;
    if (hw_e_core_count == 0 || hw_p_core_count == 0) {
        pony_syslog2("Flynn", "Warning: Actor core affinities have been disabled unable to determine core counts\n");
        hw_e_core_count = 1;
        hw_p_core_count = hw_core_count - hw_e_core_count;
        hybrid_cpu_enabled = 0;
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
    static mach_timebase_info_data_t info;
    static bool mach_timebase_init = false;
    
    if (mach_timebase_init == false) {
        if (mach_timebase_info(&info) != KERN_SUCCESS) return (uint64_t)-1.0;
        mach_timebase_init = true;
    }
    
    return mach_absolute_time () * info.numer / info.denom;
}

#endif
