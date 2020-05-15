//
//  actor.h
//  Flynn
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//
// Note: This code is derivative of the Pony runtime; see README.md for more details

#ifndef actor_h
#define actor_h

#include "messageq.h"
#include <stdint.h>
#include <stdbool.h>
#include <stdalign.h>

typedef void (^BlockCallback)(void);
typedef void (^FastBlockCallback)(void *);

typedef struct pony_actor_t
{
    messageq_t q;
    PONY_ATOMIC(uint8_t) flags;
    int32_t uid;
} pony_actor_t;

enum
{
    FLAG_SYSTEM = 1 << 0,
    FLAG_PENDINGDESTROY = 1 << 1
};

bool has_flag(pony_actor_t* actor, uint8_t flag);

pony_actor_t* ponyint_create_actor(pony_ctx_t* ctx);

void ponyint_destroy_actor(pony_actor_t* actor);

bool ponyint_actor_run(pony_ctx_t* ctx, pony_actor_t* actor);

bool ponyint_actor_pendingdestroy(pony_actor_t* actor);

void ponyint_actor_setpendingdestroy(pony_actor_t* actor);

size_t ponyint_actor_num_messages(pony_actor_t* actor);

void pony_send_block(pony_ctx_t* ctx, pony_actor_t* to, BlockCallback p);

void pony_send_fast_block(pony_ctx_t* ctx, pony_actor_t* to, void * args, FastBlockCallback p);

void pony_sendp(pony_ctx_t* ctx, pony_actor_t* to, uint32_t msgId, void* p);

void pony_send(pony_ctx_t* ctx, pony_actor_t* to, uint32_t msgId);

void pony_sendpp(pony_ctx_t* ctx, pony_actor_t* to, uint32_t msgId, void* p1, void* p2);

void pony_sendi(pony_ctx_t* ctx, pony_actor_t* to, uint32_t msgId, intptr_t i);

#endif /* actor_h */
