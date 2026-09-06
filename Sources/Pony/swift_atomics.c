// Atomic load/store primitives callable from Swift.
//
// Flynn has a number of variables which are deliberately read by one thread
// while another thread writes them: the read/write indices of Queue, the
// cached counts on TimedOperationQueue, Timer.cancelled. In every case the
// algorithm tolerates a stale value, so a lock would be the wrong fix -- but a
// plain Swift `Int` or `Bool` accessed from two threads is still a data race,
// which is undefined behaviour and is correctly reported by ThreadSanitizer.
//
// Swift has no built-in atomics and Flynn does not depend on swift-atomics, so
// these thin wrappers expose the C11 atomics the runtime already uses.
//
// The pointer passed in must be naturally aligned storage of the matching
// width, which is what UnsafeMutablePointer<Int64>.allocate(capacity: 1) and
// UnsafeMutablePointer<Bool>.allocate(capacity: 1) give you.

#include "platform.h"

#define PONY_WANT_ATOMIC_DEFS

#include "pony.h"
#include "atomics.h"

int64_t pony_atomic_load64(const void* ptr)
{
    return atomic_load_explicit((_Atomic(int64_t)*)ptr, memory_order_acquire);
}

void pony_atomic_store64(void* ptr, int64_t value)
{
    atomic_store_explicit((_Atomic(int64_t)*)ptr, value, memory_order_release);
}

int64_t pony_atomic_add64(void* ptr, int64_t delta)
{
    return atomic_fetch_add_explicit((_Atomic(int64_t)*)ptr, delta,
                                     memory_order_acq_rel) + delta;
}

bool pony_atomic_load_bool(const void* ptr)
{
    return atomic_load_explicit((_Atomic(bool)*)ptr, memory_order_acquire);
}

void pony_atomic_store_bool(void* ptr, bool value)
{
    atomic_store_explicit((_Atomic(bool)*)ptr, value, memory_order_release);
}
