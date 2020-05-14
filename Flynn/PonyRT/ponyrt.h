//
//  ponyrt.h
//  Flynn
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//
// Note: This code is derivative of the Pony runtime; see README.md for more details

#ifndef ponyrt_h
#define ponyrt_h

#include <stdio.h>
#include <assert.h>
#include <sys/types.h>
#include <stdbool.h>
#include "atomics.h"

#if defined(__LP64__)
#  define PLATFORM_IS_LP64
#else
#  define PLATFORM_IS_ILP32
#endif

typedef void (^PonyCallback)(void);

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
    uint32_t index;
    uint32_t id;
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

typedef struct pony_msgb_t
{
    pony_msg_t msg;
    PonyCallback p;
} pony_msgb_t;

#endif /* ponyrt_h */
