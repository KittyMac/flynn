//
//  ponyrt.h
//  Flynn
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#ifndef ponyrt_h
#define ponyrt_h

#include <stdio.h>
#include <assert.h>
#include <sys/types.h>
#include <stdbool.h>
#include "atomics.h"

#define COREAFFINITY_PREFER_TO_ONLY(x) (x + kCoreAffinity_OnlyThreshold)


#define kMessageBlock 1
#define kMessageFastBlock0 2
#define kMessageFastBlock1 3
#define kMessageFastBlock2 4
#define kMessageFastBlock3 5
#define kMessageFastBlock4 6
#define kMessageFastBlock5 7
#define kMessageFastBlock6 8
#define kMessageFastBlock7 9
#define kMessageFastBlock8 10
#define kMessageFastBlock9 11
#define kMessageFastBlock10 12

#ifndef id
#define id void*
#endif

typedef void (^BlockCallback)(void);
typedef void (^FastBlockCallback0)(void);
typedef void (^FastBlockCallback1)(id);
typedef void (^FastBlockCallback2)(id, id);
typedef void (^FastBlockCallback3)(id, id, id);
typedef void (^FastBlockCallback4)(id, id, id, id);
typedef void (^FastBlockCallback5)(id, id, id, id, id);
typedef void (^FastBlockCallback6)(id, id, id, id, id, id);
typedef void (^FastBlockCallback7)(id, id, id, id, id, id, id);
typedef void (^FastBlockCallback8)(id, id, id, id, id, id, id, id);
typedef void (^FastBlockCallback9)(id, id, id, id, id, id, id, id, id);
typedef void (^FastBlockCallback10)(id, id, id, id, id, id, id, id, id, id);

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

typedef struct pony_msgfb0_t
{
    pony_msg_t msg;
    FastBlockCallback0 p;
} pony_msgfb0_t;

typedef struct pony_msgfb1_t
{
    pony_msg_t msg;
    FastBlockCallback1 p;
    void * a0;
} pony_msgfb1_t;

typedef struct pony_msgfb2_t
{
    pony_msg_t msg;
    FastBlockCallback2 p;
    void * a0; void * a1;
} pony_msgfb2_t;

typedef struct pony_msgfb3_t
{
    pony_msg_t msg;
    FastBlockCallback3 p;
    void * a0; void * a1; void * a2;
} pony_msgfb3_t;

typedef struct pony_msgfb4_t
{
    pony_msg_t msg;
    FastBlockCallback4 p;
    void * a0; void * a1; void * a2; void * a3;
} pony_msgfb4_t;

typedef struct pony_msgfb5_t
{
    pony_msg_t msg;
    FastBlockCallback5 p;
    void * a0; void * a1; void * a2; void * a3; void * a4;
} pony_msgfb5_t;

typedef struct pony_msgfb6_t
{
    pony_msg_t msg;
    FastBlockCallback6 p;
    void * a0; void * a1; void * a2; void * a3; void * a4; void * a5;
} pony_msgfb6_t;

typedef struct pony_msgfb7_t
{
    pony_msg_t msg;
    FastBlockCallback7 p;
    void * a0; void * a1; void * a2; void * a3; void * a4; void * a5; void * a6;
} pony_msgfb7_t;

typedef struct pony_msgfb8_t
{
    pony_msg_t msg;
    FastBlockCallback8 p;
    void * a0; void * a1; void * a2; void * a3; void * a4; void * a5; void * a6; void * a7;
} pony_msgfb8_t;

typedef struct pony_msgfb9_t
{
    pony_msg_t msg;
    FastBlockCallback9 p;
    void * a0; void * a1; void * a2; void * a3; void * a4; void * a5; void * a6; void * a7; void * a8;
} pony_msgfb9_t;

typedef struct pony_msgfb10_t
{
    pony_msg_t msg;
    FastBlockCallback10 p;
    void * a0; void * a1; void * a2; void * a3; void * a4; void * a5; void * a6; void * a7; void * a8; void * a9;
} pony_msgfb10_t;

#endif /* ponyrt_h */
