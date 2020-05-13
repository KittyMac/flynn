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

typedef struct pony_actor_t
{
    messageq_t q;
    PONY_ATOMIC(uint8_t) flags;
    bool running;
    int32_t uid;
    int32_t batch;
} pony_actor_t;

enum
{
    FLAG_SYSTEM = 1 << 0,
    FLAG_UNSCHEDULED = 1 << 1,
    FLAG_PENDINGDESTROY = 1 << 2
};

bool has_flag(pony_actor_t* actor, uint8_t flag);

pony_actor_t* ponyint_create_actor(pony_ctx_t* ctx);

void ponyint_destroy_actor(pony_actor_t* actor);

bool ponyint_actor_run(pony_ctx_t* ctx, pony_actor_t* actor);

bool ponyint_actor_pendingdestroy(pony_actor_t* actor);

void ponyint_actor_setpendingdestroy(pony_actor_t* actor);

void ponyint_actor_final(pony_ctx_t* ctx, pony_actor_t* actor);

size_t ponyint_actor_num_messages(pony_actor_t* actor);

void pony_send(pony_ctx_t* ctx, pony_actor_t* to, uint32_t id);

void pony_sendp(pony_ctx_t* ctx, pony_actor_t* to, uint32_t id, void* p);

void pony_sendi(pony_ctx_t* ctx, pony_actor_t* to, uint32_t id, intptr_t i);

#endif /* actor_h */
