
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#define PONY_WANT_ATOMIC_DEFS

#include "actor.h"
#include "scheduler.h"
#include "cpu.h"
#include "memory.h"
#include <assert.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#define MAX_THEN 1024

static __pony_thread_local uint64_t sendv_marked_idx_push = 0;
static __pony_thread_local uint64_t sendv_marked_idx_pop = 0;

static __pony_thread_local uint64_t sendv_last_then_id = 0;
static __pony_thread_local uint64_t sendv_marked_then_id[MAX_THEN] = {0};
static __pony_thread_local uint64_t sendv_marked_then_id_hash[MAX_THEN] = {0};

static __pony_thread_local const void * sendv_marked_then_id_file[MAX_THEN] = {0};
static __pony_thread_local uint64_t sendv_marked_then_id_line[MAX_THEN] = {0};

void ponyint_actor_destroy(pony_actor_t* actor);

// The flags of a given actor cannot be mutated from more than one actor at
// once, so these operations need not be atomic RMW.
bool has_flag(pony_actor_t* actor, uint8_t flag)
{
    uint8_t flags = atomic_load_explicit(&actor->flags, memory_order_relaxed);
    return (flags & flag) != 0;
}

static void set_flag(pony_actor_t* actor, uint8_t flag)
{
    uint8_t flags = atomic_load_explicit(&actor->flags, memory_order_relaxed);
    atomic_store_explicit(&actor->flags, flags | flag, memory_order_relaxed);
}

int ponyint_actor_run(pony_ctx_t* ctx, pony_actor_t* actor, int max_msgs)
{
    pony_msg_t* msg;
    int n = 0;
    
    if (actor->suspended) {
        return 0;
    }
    
    while((msg = (pony_msg_t *)ponyint_actor_messageq_pop(&actor->queue)) != NULL) {
        
        switch(msg->msgId) {
            case kMessagePointer: {
                pony_msgfunc_t * m = (pony_msgfunc_t *)msg;
                if (m->func != NULL) {
                    sendv_last_then_id = 0;
                    sendv_marked_idx_push = 0;
                    sendv_marked_idx_pop = 0;
                    m->func(m->arg);
                    
                    if (sendv_marked_idx_push != sendv_marked_idx_pop) {
                        const char * file = sendv_marked_then_id_file[sendv_marked_idx_pop];
                        uint64_t line = sendv_marked_then_id_line[sendv_marked_idx_pop];
                        fprintf(stderr, "Unbalanced then/do detected at %s:%lu\n", file, (unsigned long)line);
                        //exit(55);
                    }
                    
                    sendv_last_then_id = 0;
                    sendv_marked_idx_push = 0;
                    sendv_marked_idx_pop = 0;
                }
            } break;
            case kDestroyMessage: {
                actor->destroy = true;
            } break;
        }
        
        ponyint_actor_messageq_pop_mark_done(&actor->queue);
        
        n++;
        if (n > max_msgs || actor->yield || actor->suspended) {
            break;
        }
    }
    
    if (actor->destroy) {
        ponyint_actor_setpendingdestroy(actor);
        ponyint_messageq_markempty(&actor->queue);
        ponyint_actor_destroy(actor);
        return -1;
    }
    
    // Return true (i.e. reschedule immediately) if our queue isn't empty.
    return (int)!ponyint_messageq_markempty(&actor->queue);
}

int32_t ponyint_actor_getpriority(pony_actor_t* actor) {
    return actor->priority;
}

void ponyint_actor_setpriority(pony_actor_t* actor, int32_t priority)
{
    actor->priority = priority;
}

int32_t ponyint_actor_getbatchSize(pony_actor_t* actor) {
    return actor->batchSize;
}

void ponyint_actor_setbatchSize(pony_actor_t* actor, int32_t batchSize)
{
    actor->batchSize = batchSize;
}

int32_t ponyint_actor_getcoreAffinity(pony_actor_t* actor) {
    return actor->coreAffinity;
}

void ponyint_actor_setcoreAffinity(pony_actor_t* actor, int32_t coreAffinity)
{
    actor->coreAffinity = coreAffinity;
}

void ponyint_yield_actor(pony_actor_t* actor)
{
    actor->yield = true;
}

void ponyint_suspend_actor(pony_actor_t* actor)
{
    actor->suspended = true;
}

void ponyint_resume_actor(pony_ctx_t* ctx, pony_actor_t* actor)
{
    actor->suspended = false;
    pony_send_message(ctx, actor, NULL, 0, NULL);
    ponyint_sched_add(ctx, actor);
}

bool ponyint_actor_is_suspended(pony_actor_t* actor)
{
    return actor->suspended;
}

void ponyint_actor_destroy(pony_actor_t* actor)
{
    assert(has_flag(actor, FLAG_PENDINGDESTROY));
    
    // Make sure the actor being destroyed has finished marking its queue
    // as empty. Otherwise, it may spuriously see that tail and head are not
    // the same and fail to mark the queue as empty, resulting in it getting
    // rescheduled.
    pony_msg_t* head = NULL;
    do {
        head = atomic_load_explicit(&actor->queue.head, memory_order_relaxed);
    } while(((uintptr_t)head & (uintptr_t)1) != (uintptr_t)1);
    
    atomic_thread_fence(memory_order_acquire);
    
    ponyint_messageq_destroy(&actor->queue);
    
    int32_t typeSize = sizeof(pony_actor_t);
    ponyint_pool_free(actor, typeSize);
    
    //pony_syslog2("Flynn", "pony actor freed\n");
}

bool ponyint_actor_pendingdestroy(pony_actor_t* actor)
{
    return has_flag(actor, FLAG_PENDINGDESTROY);
}

void ponyint_actor_setpendingdestroy(pony_actor_t* actor)
{
    // This is thread-safe, even though the flag is set from the cycle detector.
    // The function is only called after the cycle detector has detected a true
    // cycle and an actor won't change its flags if it is part of a true cycle.
    // The synchronisation is done through the ACK message sent by the actor to
    // the cycle detector.
    set_flag(actor, FLAG_PENDINGDESTROY);
}

size_t ponyint_actor_num_messages(pony_actor_t* actor)
{
    size_t n = actor->queue.num_messages;
    if (n < 0) {
        return 0;
    }
    return n;
}

pony_actor_t* ponyint_create_actor(pony_ctx_t* ctx)
{
    int32_t typeSize = sizeof(pony_actor_t);
    pony_actor_t* actor = (pony_actor_t*)ponyint_pool_alloc(typeSize);
    
    memset(actor, 0, typeSize);
    
    static int32_t actorUID = 1;
    actor->uid = actorUID++;
    actor->coreAffinity = kCoreAffinity_None;
    actor->batchSize = 1000;
    
    ponyint_messageq_init(&actor->queue);

    return actor;
}

void pony_actor_mark_then_id(const void * file, uint64_t line, uint64_t column) {
    
    uint64_t next_idx = (sendv_marked_idx_push + 1) % MAX_THEN;
    
    if (next_idx == sendv_marked_idx_pop) {
        fprintf(stderr, "Fatal Error: then/do stack size exceeded at %s:%lu\n", (const char * )file, (unsigned long)line);
        exit(55);
    }
    
    uint64_t callerHash = ((uint64_t)file) + line * 1024 + column;

    // fprintf(stderr, "THEN_STACK: PUSH ID %llu IDX %llu HASH %llu\n", sendv_last_then_id, sendv_marked_idx_push, callerHash);
    sendv_marked_then_id[sendv_marked_idx_push] = sendv_last_then_id;
    sendv_marked_then_id_file[sendv_marked_idx_push] = file;
    sendv_marked_then_id_line[sendv_marked_idx_push] = line;
    sendv_marked_then_id_hash[sendv_marked_idx_push] = callerHash;
    sendv_marked_idx_push = next_idx;

    sendv_last_then_id = 0;
}

uint64_t pony_actor_get_then_id(const void * file, uint64_t line, uint64_t column) {
    if (sendv_marked_idx_push == sendv_marked_idx_pop) { return 0; }
    
    // We are allowed to match any previous then which matches our source code hash
    uint64_t callerHash = ((uint64_t)file) + line * 1024 + column;
    
    
    uint64_t potentialIdx = sendv_marked_idx_push;
    uint64_t potentialIdxDistance = 9999999999999;
    
    uint64_t idx = sendv_marked_idx_pop;
    while (idx != sendv_marked_idx_push) {
        uint64_t markedHash = sendv_marked_then_id_hash[idx];
        if (markedHash != 0) {
            uint64_t idxDistance = markedHash > callerHash ? markedHash - callerHash : callerHash - markedHash;
            
            // fprintf(stderr, "CHECK_STACK: IDX %llu with distance %llu\n", idx, idxDistance);
            if (idxDistance < potentialIdxDistance) {
                potentialIdxDistance = idxDistance;
                potentialIdx = idx;
            }
        }
        
        idx = (idx + 1) % MAX_THEN;
    }
    
    uint64_t matchedThenId = 0;
    if (potentialIdx != sendv_marked_idx_push && potentialIdxDistance < 4096) {
        
        uint64_t then_id = sendv_marked_then_id[potentialIdx];
        sendv_marked_then_id_hash[potentialIdx] = 0;
        
        // advance the pop idx as far as it will go
        while (sendv_marked_then_id_hash[sendv_marked_idx_pop] == 0 &&
               sendv_marked_idx_push != sendv_marked_idx_pop) {
            sendv_marked_idx_pop = (sendv_marked_idx_pop + 1) % MAX_THEN;
        }
        
        matchedThenId = then_id;
        
        // fprintf(stderr, "MATCH_STACK: ID %llu IDX %llu HASH %llu\n", then_id, idx, callerHash );
    }
    
    return matchedThenId;
}

void pony_sendv(pony_ctx_t* ctx, pony_actor_t* to, pony_msg_t* first, pony_msg_t* last)
{
    if(ponyint_actor_messageq_push(&to->queue, first, last))
    {
        ponyint_sched_add(ctx, to);
    }
}

void pony_send_message(pony_ctx_t* ctx, pony_actor_t* to, void * argumentPtr, uint64_t then_id, void (*handleMessageFunc)(void * message))
{
    sendv_last_then_id = then_id;
    
    pony_msgfunc_t* m = (pony_msgfunc_t*)pony_alloc_msg(sizeof(pony_msgfunc_t), kMessagePointer);
    m->arg = argumentPtr;
    m->func = handleMessageFunc;
    pony_sendv(ctx, to, &m->msg, &m->msg);
}

void pony_complete_then_message(pony_ctx_t* ctx, pony_actor_t* to, void * argumentPtr, void (*handleMessageFunc)(void * message))
{
    pony_msgfunc_t* m = (pony_msgfunc_t*)pony_alloc_msg(sizeof(pony_msgfunc_t), kMessagePointer);
    m->arg = argumentPtr;
    m->func = handleMessageFunc;
    pony_sendv(ctx, to, &m->msg, &m->msg);
}

void pony_then_message(pony_ctx_t* ctx, pony_actor_t* to, uint64_t then_id)
{
    sendv_last_then_id = then_id;
}

void ponyint_destroy_actor(pony_actor_t* actor)
{
    // For an actor to be destroyed fully, it needs to get scheduled at least one more time
    // so send it a dummy message
    pony_msgi_t* m = (pony_msgi_t*)pony_alloc_msg(sizeof(pony_msgfunc_t), kDestroyMessage);
    pony_sendv(pony_ctx(), actor, &m->msg, &m->msg);
}
