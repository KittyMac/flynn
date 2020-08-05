#ifndef _platform_h_
#define _platform_h_

#if defined(__APPLE__)
#  define PLATFORM_IS_APPLE
#elif defined(__linux__)
#  define PLATFORM_IS_LINUX
#elif defined(__FreeBSD__)
#  define PLATFORM_IS_BSD
#  define PLATFORM_IS_FREEBSD
#elif defined(__DragonFly__)
#  define PLATFORM_IS_BSD
#  define PLATFORM_IS_DRAGONFLY
#elif defined(__OpenBSD__)
#  define PLATFORM_IS_BSD
#  define PLATFORM_IS_OPENBSD
#elif defined(_WIN32)
#  define PLATFORM_IS_WINDOWS
#endif

#if defined(__LP64__)
#  define PLATFORM_IS_LP64
#else
#  define PLATFORM_IS_ILP32
#endif

#endif
