
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#ifndef sched_cpu_h
#define sched_cpu_h

#include "scheduler.h"
#include <stdint.h>
#include <stdbool.h>

#if defined(_MSC_VER) && !defined(__GNUC__) && !defined(__clang__)
#  include <intrin.h>
#endif

void ponyint_cpu_init(void);

uint32_t ponyint_p_core_count();

uint32_t ponyint_e_core_count();

uint32_t ponyint_core_count(void);

uint32_t ponyint_hybrid_cores_enabled();

void ponyint_cpu_sleep(int ns);

static inline void ponyint_cpu_relax(void)
{
#if defined(__GNUC__) || defined(__clang__)
#  if defined(__x86_64__) || defined(__i386__)
    __asm__ __volatile__("pause" ::: "memory");
#  elif defined(__aarch64__) || (defined(__arm__) && __ARM_ARCH >= 7)
    __asm__ __volatile__("yield" ::: "memory");
#  else
    // No relax instruction for this target; still act as a compiler barrier so
    // the surrounding spin loop re-reads its condition.
    __asm__ __volatile__("" ::: "memory");
#  endif
#elif defined(_MSC_VER)
#  if defined(_M_ARM64) || defined(_M_ARM)
    __yield();
#  else
    _mm_pause();
#  endif
#endif
}

void ponyint_cpu_yield(void);

uint64_t ponyint_cpu_tick(void);

#endif
