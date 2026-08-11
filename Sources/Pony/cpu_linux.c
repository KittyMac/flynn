
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
#include <malloc.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/syscall.h>
#include <sys/resource.h>
#include <sys/types.h>

#include "threads.h"

static uint32_t avail_cpu_count;

static uint32_t hw_core_count;
static uint32_t hybrid_cpu_enabled = 0;

static uint32_t hw_e_core_count = 0;
static uint32_t hw_p_core_count = 0;

// The set of cpus belonging to each class, and the normalized capacity (0..1024)
// of the fastest efficiency core. Only meaningful when hybrid_cpu_enabled != 0.
static cpu_set_t hw_e_cpus;
static cpu_set_t hw_p_cpus;
static uint32_t hw_e_capacity = 0;

// Hard pinning is opt-in (FLYNN_PIN_CORES=1). See ponyint_cpu_apply_thread_affinity().
static bool hw_pin_cores = false;

void pony_usleep(uint64_t usec)
{
    usleep(usec);
}

void pony_malloc_trim(size_t pad) {
#if defined(__GLIBC__)
    malloc_trim(pad);
#endif
}

// ---------------------------------------------------------------------------
// efficiency / performance core detection
//
// Unlike Darwin there is no single "give me the perflevels" call, so we try
// three sources in descending order of trustworthiness and stop at the first
// one that yields both classes:
//
//   1. Intel hybrid (Alder Lake and later). The perf subsystem publishes
//      /sys/devices/cpu_atom/cpus and /sys/devices/cpu_core/cpus. Exact, cheap,
//      unprivileged. x86 does not export cpu_capacity, so this is the only good
//      signal there.
//   2. arm64 capacity aware scheduling: cpu_capacity, normalized so that the
//      fastest core reads 1024. Present on every Android device and on most
//      arm64 SBCs and server parts.
//   3. cpufreq max frequency ratios. Weakest signal (some SoCs report the same
//      max freq for clusters with very different IPC) but better than nothing.
//
// Anything we cannot classify stays "performance", so an unrecognized machine
// behaves exactly the way Flynn behaves today.
// ---------------------------------------------------------------------------

static bool cpu_read_text(const char* path, char* buf, size_t len)
{
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if(fd < 0)
        return false;

    ssize_t n = read(fd, buf, len - 1);
    close(fd);

    if(n <= 0)
        return false;

    buf[n] = '\0';
    return true;
}

static bool cpu_read_u64(const char* path, uint64_t* out)
{
    char buf[64];
    if(!cpu_read_text(path, buf, sizeof(buf)))
        return false;

    errno = 0;
    char* end = NULL;
    unsigned long long v = strtoull(buf, &end, 10);
    if(end == buf || errno != 0)
        return false;

    *out = (uint64_t)v;
    return true;
}

// Parses a kernel cpu list such as "0-7,16,20-23".
static bool cpu_parse_list(const char* s, cpu_set_t* out)
{
    CPU_ZERO(out);
    bool any = false;

    while(*s)
    {
        while(*s == ',' || *s == ' ' || *s == '\n')
            s++;
        if(*s == '\0')
            break;

        char* end = NULL;
        long lo = strtol(s, &end, 10);
        if(end == s)
            break;
        s = end;

        long hi = lo;
        if(*s == '-')
        {
            s++;
            hi = strtol(s, &end, 10);
            if(end == s)
                break;
            s = end;
        }

        for(long i = lo; i <= hi && i < CPU_SETSIZE; i++)
        {
            if(i >= 0)
            {
                CPU_SET((int)i, out);
                any = true;
            }
        }
    }

    return any;
}

static bool cpu_read_list_file(const char* path, cpu_set_t* out)
{
    char buf[512];
    if(!cpu_read_text(path, buf, sizeof(buf)))
        return false;
    return cpu_parse_list(buf, out);
}

// Highest cpu id the kernel knows about, +1.
static uint32_t cpu_present_count()
{
    cpu_set_t present;
    if(cpu_read_list_file("/sys/devices/system/cpu/present", &present))
    {
        for(int i = CPU_SETSIZE - 1; i >= 0; i--)
        {
            if(CPU_ISSET(i, &present))
                return (uint32_t)(i + 1);
        }
    }

    long conf = sysconf(_SC_NPROCESSORS_CONF);
    if(conf <= 0)
        conf = 1;
    if(conf > CPU_SETSIZE)
        conf = CPU_SETSIZE;
    return (uint32_t)conf;
}

// 1. Intel hybrid via the perf pmu directories.
static bool cpu_detect_intel_hybrid(uint32_t ncpus)
{
    cpu_set_t atom;
    cpu_set_t core;

    if(!cpu_read_list_file("/sys/devices/cpu_atom/cpus", &atom))
        return false;
    if(!cpu_read_list_file("/sys/devices/cpu_core/cpus", &core))
        return false;

    for(uint32_t i = 0; i < ncpus; i++)
    {
        if(CPU_ISSET(i, &atom))
            CPU_SET(i, &hw_e_cpus);
        else if(CPU_ISSET(i, &core))
            CPU_SET(i, &hw_p_cpus);
    }

    if(CPU_COUNT(&hw_e_cpus) == 0 || CPU_COUNT(&hw_p_cpus) == 0)
        return false;

    // x86 exposes no capacity metric; 512 is a neutral "small core" hint. It is
    // only ever used for uclamp, which Intel hybrid kernels largely ignore
    // anyway (no EAS), so pinning is what actually does the work there.
    hw_e_capacity = 512;
    pony_syslog2("Flynn", "hybrid cpu detected (intel cpu_atom/cpu_core): %d efficiency, %d performance\n",
                 CPU_COUNT(&hw_e_cpus), CPU_COUNT(&hw_p_cpus));
    return true;
}

// 2 and 3. Capacity aware scheduling, or cpufreq as a fallback.
static bool cpu_detect_by_capacity(uint32_t ncpus, bool use_cpufreq)
{
    uint64_t raw[CPU_SETSIZE];
    memset(raw, 0, sizeof(raw));

    uint64_t raw_max = 0;
    uint32_t found = 0;

    for(uint32_t i = 0; i < ncpus; i++)
    {
        char path[FILENAME_MAX];
        if(use_cpufreq)
            snprintf(path, sizeof(path),
                     "/sys/devices/system/cpu/cpu%d/cpufreq/cpuinfo_max_freq", i);
        else
            snprintf(path, sizeof(path),
                     "/sys/devices/system/cpu/cpu%d/cpu_capacity", i);

        uint64_t v = 0;
        if(!cpu_read_u64(path, &v) || v == 0)
            continue;

        raw[i] = v;
        if(v > raw_max)
            raw_max = v;
        found++;
    }

    if(found < 2 || raw_max == 0)
        return false;

    // A core is "efficiency" if it sits meaningfully below the top capacity.
    // 3/4 keeps prime + gold together on the usual 1+3+4 arm64 layouts while
    // still catching the silver cluster.
    const uint32_t threshold = (1024u * 3u) / 4u;

    for(uint32_t i = 0; i < ncpus; i++)
    {
        if(raw[i] == 0)
            continue;

        uint32_t capacity = (uint32_t)((raw[i] * 1024ull) / raw_max);
        if(capacity < threshold)
        {
            CPU_SET(i, &hw_e_cpus);
            if(capacity > hw_e_capacity)
                hw_e_capacity = capacity;
        }
        else
        {
            CPU_SET(i, &hw_p_cpus);
        }
    }

    if(CPU_COUNT(&hw_e_cpus) == 0 || CPU_COUNT(&hw_p_cpus) == 0)
        return false;

    pony_syslog2("Flynn", "hybrid cpu detected (%s): %d efficiency, %d performance, e-capacity %d/1024\n",
                 use_cpufreq ? "cpufreq" : "cpu_capacity",
                 CPU_COUNT(&hw_e_cpus), CPU_COUNT(&hw_p_cpus), hw_e_capacity);
    return true;
}

// Escape hatch for CI, containers and bring-up on hardware we misread:
//   FLYNN_ECORES=0-3 FLYNN_PCORES=4-7
static bool cpu_detect_from_env(uint32_t ncpus)
{
    const char* e = getenv("FLYNN_ECORES");
    const char* p = getenv("FLYNN_PCORES");

    if(e == NULL && p == NULL)
        return false;

    cpu_set_t eset;
    cpu_set_t pset;
    CPU_ZERO(&eset);
    CPU_ZERO(&pset);

    if(e != NULL)
        cpu_parse_list(e, &eset);
    if(p != NULL)
        cpu_parse_list(p, &pset);

    for(uint32_t i = 0; i < ncpus; i++)
    {
        if(CPU_ISSET(i, &eset))
            CPU_SET(i, &hw_e_cpus);
        else if(CPU_ISSET(i, &pset))
            CPU_SET(i, &hw_p_cpus);
    }

    if(CPU_COUNT(&hw_e_cpus) == 0 || CPU_COUNT(&hw_p_cpus) == 0)
        return false;

    hw_e_capacity = 1024 / 4;
    pony_syslog2("Flynn", "hybrid cpu overridden by environment: %d efficiency, %d performance\n",
                 CPU_COUNT(&hw_e_cpus), CPU_COUNT(&hw_p_cpus));
    return true;
}

static bool cpu_detect_hybrid()
{
    uint32_t ncpus = cpu_present_count();

    CPU_ZERO(&hw_e_cpus);
    CPU_ZERO(&hw_p_cpus);
    hw_e_capacity = 0;

    if(cpu_detect_from_env(ncpus))
        return true;

    CPU_ZERO(&hw_e_cpus);
    CPU_ZERO(&hw_p_cpus);
    if(cpu_detect_intel_hybrid(ncpus))
        return true;

    CPU_ZERO(&hw_e_cpus);
    CPU_ZERO(&hw_p_cpus);
    hw_e_capacity = 0;
    if(cpu_detect_by_capacity(ncpus, false))
        return true;

    CPU_ZERO(&hw_e_cpus);
    CPU_ZERO(&hw_p_cpus);
    hw_e_capacity = 0;
    if(cpu_detect_by_capacity(ncpus, true))
        return true;

    CPU_ZERO(&hw_e_cpus);
    CPU_ZERO(&hw_p_cpus);
    hw_e_capacity = 0;
    return false;
}

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

void ponyint_cpu_init()
{
    cpu_set_t all_cpus;
    cpu_set_t hw_cpus;
    cpu_set_t ht_cpus;
    
    sched_getaffinity(0, sizeof(cpu_set_t), &all_cpus);
    CPU_ZERO(&hw_cpus);
    CPU_ZERO(&ht_cpus);
    
    uint32_t avail_cpu_size = avail_cpu_count = CPU_COUNT(&all_cpus);
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
        
    hw_core_count = CPU_COUNT(&ht_cpus) + CPU_COUNT(&hw_cpus);
    
#if __ANDROID__
    // On Android specifically, the sched_getaffinity() for unreliable. To combat this, we're going to
    // detected when then hw_core_count < 4 and up it to 8.
    if (hw_core_count < 4) {
        hw_core_count = 8;
    }
#endif
    
    if (cpu_detect_hybrid()) {
        hw_e_core_count = (uint32_t)CPU_COUNT(&hw_e_cpus);
        hw_p_core_count = (uint32_t)CPU_COUNT(&hw_p_cpus);
        hybrid_cpu_enabled = 1;

        // Prefer the sysfs view of the machine over sched_getaffinity(), which
        // is what the Android workaround above exists to paper over.
        uint32_t detected = hw_e_core_count + hw_p_core_count;
        if (detected > hw_core_count) {
            hw_core_count = detected;
        }

        const char * pin = getenv("FLYNN_PIN_CORES");
        hw_pin_cores = (pin != NULL && pin[0] == '1');
    }

    if (hw_e_core_count == 0 || hw_p_core_count == 0) {
        pony_syslog2("Flynn", "Warning: Actor core affinities have been disabled, unrecognized cpu detected\n");
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

// ---------------------------------------------------------------------------
// per thread placement
//
// Two mechanisms, and they are not interchangeable:
//
//   uclamp (sched_setattr + SCHED_FLAG_UTIL_CLAMP_MAX, Linux 5.3+) is a *hint*.
//   On capacity/energy aware kernels a low uclamp_max biases wakeup placement
//   onto the little cluster and caps the frequency schedutil requests for the
//   thread. This is the honest analogue of QOS_CLASS_UTILITY and is what we do
//   by default. Two caveats worth knowing: uclamp max-aggregates per runqueue,
//   so a capped thread sharing an rq with an uncapped one will not actually get
//   its frequency capped (placement bias still applies); and an unprivileged
//   task may lower uclamp_max but generally may not raise it again without
//   CAP_SYS_NICE, which is why we only ever lower it, only on E schedulers, and
//   only once at thread start.
//
//   sched_setaffinity is a *fence*. It is the only thing that works on Intel
//   hybrid (no EAS there), but an E-pinned scheduler cannot spill onto idle P
//   cores, which breaks the fall-back half of kCoreAffinity_PreferEfficiency.
//   On Android it is also fragile: when the framework moves the process between
//   cpusets on lifecycle changes the new cpuset mask overwrites cpus_allowed
//   and the pinning silently evaporates. Opt-in only, via FLYNN_PIN_CORES=1.
// ---------------------------------------------------------------------------

#ifndef SCHED_FLAG_KEEP_POLICY
#define SCHED_FLAG_KEEP_POLICY    0x08
#endif
#ifndef SCHED_FLAG_KEEP_PARAMS
#define SCHED_FLAG_KEEP_PARAMS    0x10
#endif
#ifndef SCHED_FLAG_UTIL_CLAMP_MAX
#define SCHED_FLAG_UTIL_CLAMP_MAX 0x40
#endif

// Layout must match the kernel's struct sched_attr. Do not reorder. There is no
// libc wrapper for sched_setattr() in glibc, musl or bionic.
struct pony_sched_attr {
    uint32_t size;
    uint32_t sched_policy;
    uint64_t sched_flags;
    int32_t  sched_nice;
    uint32_t sched_priority;
    uint64_t sched_runtime;
    uint64_t sched_deadline;
    uint64_t sched_period;
    uint32_t sched_util_min;
    uint32_t sched_util_max;
};

static bool cpu_set_uclamp_max(uint32_t util_max)
{
#ifdef __NR_sched_setattr
    struct pony_sched_attr attr;
    memset(&attr, 0, sizeof(attr));
    attr.size = sizeof(attr);
    attr.sched_flags = SCHED_FLAG_KEEP_POLICY | SCHED_FLAG_KEEP_PARAMS |
                       SCHED_FLAG_UTIL_CLAMP_MAX;
    attr.sched_util_max = (util_max > 1024) ? 1024 : util_max;

    // pid 0 means the calling thread
    return syscall(__NR_sched_setattr, 0, &attr, 0u) == 0;
#else
    (void)util_max;
    return false;
#endif
}

static bool cpu_pin_to(const cpu_set_t* desired)
{
    cpu_set_t allowed;
    cpu_set_t target;

    if(sched_getaffinity(0, sizeof(cpu_set_t), &allowed) != 0)
        return false;

    CPU_AND(&target, desired, &allowed);

    // If a cpuset or taskset has already excluded every cpu of this class,
    // leaving the thread unrestricted beats pinning it to nothing.
    if(CPU_COUNT(&target) == 0)
        return false;

    return sched_setaffinity(0, sizeof(cpu_set_t), &target) == 0;
}

void ponyint_cpu_apply_thread_affinity(int coreAffinity)
{
    if(hybrid_cpu_enabled == 0)
        return;

    if(coreAffinity == kCoreAffinity_OnlyEfficiency)
    {
        // Tell the scheduler this thread fits on a small core.
        cpu_set_uclamp_max(hw_e_capacity > 0 ? hw_e_capacity : (1024 / 4));

        // A gentle nice bump so E schedulers yield to P schedulers under
        // contention. Per-thread on Linux because threads are tasks. Note this
        // is deliberately not SCHED_IDLE, which would invite starvation given
        // that a running actor cannot be preempted by its scheduler.
        setpriority(PRIO_PROCESS, (id_t)syscall(SYS_gettid), 5);

        if(hw_pin_cores)
            cpu_pin_to(&hw_e_cpus);
    }
    else if(coreAffinity == kCoreAffinity_OnlyPerformance)
    {
        // Never lower uclamp on P schedulers: for an unprivileged process that
        // is a one-way door. Unrestricted is the correct default here.
        if(hw_pin_cores)
            cpu_pin_to(&hw_p_cpus);
    }
}

void ponyint_cpu_sleep(int ns)
{
    usleep(ns);
}

void ponyint_cpu_yield()
{
    sched_yield();
}

uint64_t ponyint_cpu_tick()
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}

#endif
