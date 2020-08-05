//
//  actor.h
//  Flynn
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#ifndef actor_h
#define actor_h

#include "messageq.h"
#include "ponyrt.h"
#include <stdint.h>
#include <stdbool.h>
#include <stdalign.h>

typedef struct pony_actor_t
{
    messageq_t q;
    PONY_ATOMIC(uint8_t) flags;
    int32_t uid;
    int32_t priority;
    int32_t coreAffinity;
    bool yield;
    void * swiftActor;
} pony_actor_t;

enum
{
    FLAG_SYSTEM = 1 << 0,
    FLAG_PENDINGDESTROY = 1 << 1
};

bool has_flag(pony_actor_t* actor, uint8_t flag);

pony_actor_t* ponyint_create_actor(pony_ctx_t* ctx, void * swiftActor);

void ponyint_destroy_actor(pony_actor_t* actor);

bool ponyint_actor_run(pony_ctx_t* ctx, pony_actor_t* actor, int max_msgs);

int32_t ponyint_actor_getpriority(pony_actor_t* actor);
void ponyint_actor_setpriority(pony_actor_t* actor, int32_t priority);

int32_t ponyint_actor_getcoreAffinity(pony_actor_t* actor);
void ponyint_actor_setcoreAffinity(pony_actor_t* actor, int32_t coreAffinity);

void ponyint_yield_actor(pony_actor_t* actor);

bool ponyint_actor_pendingdestroy(pony_actor_t* actor);

void ponyint_actor_setpendingdestroy(pony_actor_t* actor);

size_t ponyint_actor_num_messages(pony_actor_t* actor);

void pony_send_fast_block0(pony_ctx_t* ctx, pony_actor_t* to, FastBlockCallback0 p);
void pony_send_fast_block1(pony_ctx_t* ctx, pony_actor_t* to, id arg0, FastBlockCallback1 p);
void pony_send_fast_block2(pony_ctx_t* ctx, pony_actor_t* to, id arg0, id arg1, FastBlockCallback2 p);
void pony_send_fast_block3(pony_ctx_t* ctx, pony_actor_t* to, id arg0, id arg1, id arg2, FastBlockCallback3 p);
void pony_send_fast_block4(pony_ctx_t* ctx, pony_actor_t* to, id arg0, id arg1, id arg2, id arg3, FastBlockCallback4 p);
void pony_send_fast_block5(pony_ctx_t* ctx, pony_actor_t* to, id arg0, id arg1, id arg2, id arg3, id arg4, FastBlockCallback5 p);
void pony_send_fast_block6(pony_ctx_t* ctx, pony_actor_t* to, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5, FastBlockCallback6 p);
void pony_send_fast_block7(pony_ctx_t* ctx, pony_actor_t* to, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6, FastBlockCallback7 p);
void pony_send_fast_block8(pony_ctx_t* ctx, pony_actor_t* to, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6, id arg7, FastBlockCallback8 p);
void pony_send_fast_block9(pony_ctx_t* ctx, pony_actor_t* to, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6, id arg7, id arg8, FastBlockCallback9 p);
void pony_send_fast_block10(pony_ctx_t* ctx, pony_actor_t* to, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6, id arg7, id arg8, id arg9, FastBlockCallback10 p);

#endif /* actor_h */
