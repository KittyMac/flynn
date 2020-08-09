
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
    int32_t batchSize;
    bool yield;
    bool destroy;
} pony_actor_t;

enum
{
    FLAG_SYSTEM = 1 << 0,
    FLAG_PENDINGDESTROY = 1 << 1
};

bool has_flag(pony_actor_t* actor, uint8_t flag);

pony_actor_t* ponyint_create_actor(pony_ctx_t* ctx);

void ponyint_destroy_actor(pony_actor_t* actor);

bool ponyint_actor_run(pony_ctx_t* ctx, pony_actor_t* actor, int max_msgs);

int32_t ponyint_actor_getpriority(pony_actor_t* actor);
void ponyint_actor_setpriority(pony_actor_t* actor, int32_t priority);

int32_t ponyint_actor_getbatchSize(pony_actor_t* actor);
void ponyint_actor_setbatchSize(pony_actor_t* actor, int32_t batchSize);

int32_t ponyint_actor_getcoreAffinity(pony_actor_t* actor);
void ponyint_actor_setcoreAffinity(pony_actor_t* actor, int32_t coreAffinity);

void ponyint_yield_actor(pony_actor_t* actor);

bool ponyint_actor_pendingdestroy(pony_actor_t* actor);

void ponyint_actor_setpendingdestroy(pony_actor_t* actor);

size_t ponyint_actor_num_messages(pony_actor_t* actor);

void pony_send_message(pony_ctx_t* ctx, pony_actor_t* to, void * argumentPtr, void (*handleMessageFunc)(void * message));

#endif /* actor_h */
