
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#ifndef ponyrt_h
#define ponyrt_h

#include <stdio.h>
#include <assert.h>
#include <sys/types.h>
#include <stdbool.h>
#include "atomics.h"

void pony_set_thread_name(const char * name);
void pony_syslog(const char * tag, const char * msg);
void pony_syslog2(const char * tag, const char *format, ...);
char * pony_dns_resolve_cname(const char * domain);
char * pony_dns_resolve_txt(const char * domain);

#define kDestroyMessage 0
#define kMessagePointer 1

typedef struct pony_actor_t pony_actor_t;

typedef struct pony_ctx_t pony_ctx_t;

/** Message header.
 *
 * This must be the first field in any message structure. The ID is used for
 * dispatch. The index is a pool allocator index and is used for freeing the
 * message. The next pointer should not be read or set.
 */
typedef struct pony_msg_t pony_msg_t;

struct pony_msg_t
{
    uint32_t alloc_size;
    uint32_t msgId;
    PONY_ATOMIC(pony_msg_t*) next;
};

/// Convenience message for sending an integer.
typedef struct pony_msgi_t
{
    pony_msg_t msg;
    intptr_t i;
} pony_msgi_t;

/// Convenience message for sending a pointer.
typedef struct pony_msgp_t
{
    pony_msg_t msg;
    void* p;
} pony_msgp_t;

/// Convenience message for sending two pointers.
typedef struct pony_msgpp_t
{
    pony_msg_t msg;
    void* p1;
    void* p2;
} pony_msgpp_t;

/// Convenience message for sending two pointers.
typedef struct pony_msgfunc_t
{
    pony_msg_t msg;
    void* arg;
    void (*func)(void * message);
    void (*releaseFunc)(void * message);
} pony_msgfunc_t;

#endif /* ponyrt_h */
