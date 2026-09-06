
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

static bool actor_park(pony_actor_t* actor)
{
    atomic_store_explicit(&actor->parked, true, memory_order_seq_cst);
    
    if(atomic_load_explicit(&actor->suspended, memory_order_seq_cst)) {
        // Still suspended. ponyint_resume_actor() owns the actor now.
        return false;
    }
    
    // Resumed underneath us. Whoever wins the exchange does the rescheduling.
    return atomic_exchange_explicit(&actor->parked, false, memory_order_acq_rel);
}

static bool actor_unsuspend(pony_actor_t* actor)
{
    atomic_store_explicit(&actor->suspended, false, memory_order_seq_cst);
    return atomic_exchange_explicit(&actor->parked, false, memory_order_acq_rel);
}

// Snapshot the fields the scheduler reads after we return. Must be called
// before every release point -- see actor_run_info_t in actor.h.
static void actor_snapshot(pony_actor_t* actor, actor_run_info_t* out)
{
    if (out == NULL) { return; }
    out->yielded      = atomic_load_explicit(&actor->yield, memory_order_relaxed);
    out->priority     = actor->priority;
    out->coreAffinity = actor->coreAffinity;
}

int ponyint_actor_run(pony_ctx_t* ctx, pony_actor_t* actor, int max_msgs,
                      actor_run_info_t* out)
{
    pony_msg_t* msg;
    int n = 0;
    
    atomic_store_explicit(&actor->yield, false, memory_order_relaxed);
    
    if(atomic_load_explicit(&actor->suspended, memory_order_acquire)) {
        actor_snapshot(actor, out);
        return actor_park(actor) ? 1 : 0;
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
        if (n > max_msgs ||
            atomic_load_explicit(&actor->yield, memory_order_relaxed) ||
            atomic_load_explicit(&actor->suspended, memory_order_relaxed)) {
            break;
        }
    }
    
    if (actor->destroy) {
        actor_snapshot(actor, out);
        // Note this is checked before the suspended/park branch below on purpose:
        // a destroying actor must never park, or it would never be freed.
        // Claim the queue rather than marking it empty. markempty() sets the
        // empty bit, which PUBLISHES the actor -- a sender would then schedule
        // it onto another scheduler while we free it, which is the
        // use-after-free ASan reported. markdestroyed() sets a different bit
        // that no sender treats as "unscheduled", so once it succeeds we are
        // the actor's sole owner.
        if(!ponyint_messageq_markdestroyed(&actor->queue)) {
            return 1;
        }
        
        ponyint_actor_setpendingdestroy(actor);
        ponyint_actor_destroy(actor);
        return -1;
    }
    
    // A behaviour may have suspended us part way through the batch. The queue
    // can still hold messages, so we must not mark it empty -- park instead.
    if(atomic_load_explicit(&actor->suspended, memory_order_acquire)) {
        actor_snapshot(actor, out);
        return actor_park(actor) ? 1 : 0;
    }
    
    // Return true (i.e. reschedule immediately) if our queue isn't empty.
    //
    // Snapshot BEFORE markempty: if it succeeds the actor is published and may
    // already be running on another scheduler. Nothing below this point, here
    // or in the caller, may touch `actor`.
    actor_snapshot(actor, out);
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

void ponyint_actor_setProfileTypeID(pony_actor_t* actor, int32_t typeID)
{
    actor->profileTypeID = typeID;
}

void ponyint_yield_actor(pony_actor_t* actor)
{
    atomic_store_explicit(&actor->yield, true, memory_order_relaxed);
}

void ponyint_suspend_actor(pony_actor_t* actor)
{
    atomic_store_explicit(&actor->suspended, true, memory_order_seq_cst);
}

void ponyint_resume_actor(pony_ctx_t* ctx, pony_actor_t* actor)
{
    if(actor_unsuspend(actor)) {
        ponyint_sched_add(ctx, actor);
        return;
    }
    
    pony_send_message(ctx, actor, NULL, 0, NULL, NULL);
}

bool ponyint_actor_is_suspended(pony_actor_t* actor)
{
    return atomic_load_explicit(&actor->suspended, memory_order_acquire);
}

void ponyint_actor_destroy(pony_actor_t* actor)
{
    assert(has_flag(actor, FLAG_PENDINGDESTROY));
    
    // The queue must carry the DESTROYED sentinel (bit 1), set by
    // ponyint_messageq_markdestroyed(). This used to check the EMPTY bit
    // (bit 0), which the destroy path no longer sets -- deliberately, since
    // setting it would publish the actor to the next sender.
    pony_msg_t* head = atomic_load_explicit(&actor->queue.head, memory_order_acquire);
    if(((uintptr_t)head & (uintptr_t)2) != (uintptr_t)2) {
        pony_syslog2("Flynn", "ponyint_actor_destroy: queue not claimed for actor %d, leaking", actor->uid);
        return;
    }
    
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
    
    static PONY_ATOMIC(int32_t) actorUID = 1;
    actor->uid = atomic_fetch_add_explicit(&actorUID, 1, memory_order_relaxed);
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

// Discard a message chain that was never queued: release each payload, then
// free the structs. Today the chain is always a single message.
static void sendv_discard(pony_msg_t* first)
{
    pony_msg_t* msg = first;
    while(msg != NULL) {
        pony_msg_t* next = atomic_load_explicit(&msg->next, memory_order_relaxed);
        if(msg->msgId == kMessagePointer) {
            pony_msgfunc_t* m = (pony_msgfunc_t*)msg;
            if(m->releaseFunc != NULL) {
                m->releaseFunc(m->arg);
            }
        }
        ponyint_pool_free(msg, msg->alloc_size);
        msg = next;
    }
}

void pony_sendv(pony_ctx_t* ctx, pony_actor_t* to, pony_msg_t* first, pony_msg_t* last)
{
    push_result_t pushed = ponyint_actor_messageq_push(&to->queue, first, last);
    
    if(pushed == kPushRefused) {
        // The actor is being destroyed. We still own the message, so release it
        // here rather than leaking the Swift block it carries.
        sendv_discard(first);
        return;
    }
    
    if(pushed == kPushWasEmpty)
    {
        ponyint_sched_add(ctx, to);
    }
}

void pony_send_message(pony_ctx_t* ctx, pony_actor_t* to, void * argumentPtr, uint64_t then_id, void (*handleMessageFunc)(void * message), void (*releaseMessageFunc)(void * message))
{
    sendv_last_then_id = then_id;
    
    pony_msgfunc_t* m = (pony_msgfunc_t*)pony_alloc_msg(sizeof(pony_msgfunc_t), kMessagePointer);
    m->arg = argumentPtr;
    m->func = handleMessageFunc;
    m->releaseFunc = releaseMessageFunc;
    pony_sendv(ctx, to, &m->msg, &m->msg);
}

void pony_complete_then_message(pony_ctx_t* ctx, pony_actor_t* to, void * argumentPtr, void (*handleMessageFunc)(void * message), void (*releaseMessageFunc)(void * message))
{
    pony_msgfunc_t* m = (pony_msgfunc_t*)pony_alloc_msg(sizeof(pony_msgfunc_t), kMessagePointer);
    m->arg = argumentPtr;
    m->func = handleMessageFunc;
    m->releaseFunc = releaseMessageFunc;
    pony_sendv(ctx, to, &m->msg, &m->msg);
}

void pony_then_message(pony_ctx_t* ctx, pony_actor_t* to, uint64_t then_id)
{
    sendv_last_then_id = then_id;
}

void ponyint_destroy_actor(pony_actor_t* actor)
{
    pony_ctx_t* ctx = pony_ctx();
    
    // For an actor to be destroyed fully, it needs to get scheduled at least one more time
    // so send it a dummy message
    bool was_parked = actor_unsuspend(actor);
    pony_msgi_t* m = (pony_msgi_t*)pony_alloc_msg(sizeof(pony_msgfunc_t), kDestroyMessage);
    push_result_t pushed = ponyint_actor_messageq_push(&actor->queue, &m->msg, &m->msg);
    
    if(pushed == kPushRefused) {
        // Already claimed for destruction -- a second destroy request. Nothing
        // to schedule; discard our dummy message. kDestroyMessage carries no
        // payload, so there is nothing to release.
        ponyint_pool_free(&m->msg, m->msg.alloc_size);
        return;
    }
    
    if (was_parked || pushed == kPushWasEmpty) {
        ponyint_sched_add(ctx, actor);
    }
}
