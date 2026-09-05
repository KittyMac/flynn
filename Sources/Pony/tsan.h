// Note: This code is derivative of the Pony runtime; see README.md for more details

#ifndef pony_tsan_h
#define pony_tsan_h

// Happens-before annotations for ThreadSanitizer.
//
// The runtime publishes data with a relaxed store paired with a standalone
// release fence, and consumes it with a relaxed load paired with a standalone
// acquire fence. ThreadSanitizer does not model standalone fences:
// __tsan_atomic_thread_fence is effectively a no-op inside the sanitizer
// runtime. A relaxed load followed by an acquire fence therefore yields zero
// synchronisation from TSAN's point of view, and every subsequent access to
// the transferred data is reported as a data race.
//
// These macros hand TSAN the edge explicitly. They compile to nothing unless
// the translation unit is built with -fsanitize=thread, so there is no cost in
// normal builds and the algorithms themselves are unchanged.
//
//   PONY_HB_BEFORE(addr) - publishing side, after the writes being published
//                          and immediately before the release fence.
//   PONY_HB_AFTER(addr)  - consuming side, immediately after the acquire fence
//                          and before touching the published data.
//
// `addr` is only a token identifying the edge; it is never dereferenced. The
// same address must be used on both sides.

#if defined(__has_feature)
#  if __has_feature(thread_sanitizer)
#    define PONY_TSAN_ENABLED 1
#  endif
#endif

#if !defined(PONY_TSAN_ENABLED) && defined(__SANITIZE_THREAD__)
#  define PONY_TSAN_ENABLED 1
#endif

#ifdef PONY_TSAN_ENABLED

#ifdef __cplusplus
extern "C" {
#endif

// Exported by the compiler-rt ThreadSanitizer runtime; see tsan_interface.h.
// Declared here so the sanitizer headers are not required on the include path.
void __tsan_acquire(void* addr);
void __tsan_release(void* addr);

#ifdef __cplusplus
}
#endif

#define PONY_HB_BEFORE(addr) __tsan_release((void*)(addr))
#define PONY_HB_AFTER(addr)  __tsan_acquire((void*)(addr))

#else

#define PONY_HB_BEFORE(addr) ((void)0)
#define PONY_HB_AFTER(addr)  ((void)0)

#endif

#endif /* pony_tsan_h */
