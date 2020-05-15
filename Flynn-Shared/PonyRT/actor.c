//
//  actor.c
//  Flynn
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//
// Note: This code is derivative of the Pony runtime; see README.md for more details

#define PONY_WANT_ATOMIC_DEFS

#include "block.h"
#include "actor.h"
#include "scheduler.h"
#include "cpu.h"
#include "pool.h"
#include <assert.h>
#include <string.h>
#include <stdio.h>

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
/*
static void unset_flag(pony_actor_t* actor, uint8_t flag)
{
    uint8_t flags = atomic_load_explicit(&actor->flags, memory_order_relaxed);
    atomic_store_explicit(&actor->flags, flags & (uint8_t)~flag,
                          memory_order_relaxed);
}
*/
bool ponyint_actor_run(pony_ctx_t* ctx, pony_actor_t* actor)
{
    pony_msg_t* msg;
    
    while((msg = (pony_msg_t *)ponyint_actor_messageq_pop(&actor->q)) != NULL) {
        
        if (msg->msgId == kMessageBlock) {
            pony_msgb_t * msgb = (pony_msgb_t *)msg;
            msgb->p();
            Block_release_pony(msgb->p);
        } else if (msg->msgId == kMessageFastBlock) {
            pony_msgfb_t * msgfb = (pony_msgfb_t *)msg;
            msgfb->p(msgfb->a);
            objc_autorelease(msgfb->a);
        }
        
        ponyint_actor_messageq_pop_mark_done(&actor->q);
    }
    
    // Return true (i.e. reschedule immediately) if our queue isn't empty.
    return !ponyint_messageq_markempty(&actor->q);
}

void ponyint_actor_destroy(pony_actor_t* actor)
{
    assert(has_flag(actor, FLAG_PENDINGDESTROY));
    
    // Make sure the actor being destroyed has finished marking its queue
    // as empty. Otherwise, it may spuriously see that tail and head are not
    // the same and fail to mark the queue as empty, resulting in it getting
    // rescheduled.
    pony_msg_t* head = NULL;
    do
    {
        head = atomic_load_explicit(&actor->q.head, memory_order_relaxed);
    } while(((uintptr_t)head & (uintptr_t)1) != (uintptr_t)1);
    
    atomic_thread_fence(memory_order_acquire);
    
    ponyint_messageq_destroy(&actor->q);
    
    int32_t typeSize = sizeof(actor);
    
    // Note: While the memset to 0 is not strictly necessary, there were quite
    // a few "access the actor after it was deleted" bugs going by
    // undetected because the contents of the memory just hadn't been
    // changed yet.  Leaving this code in as a reminder to help hunt
    // down such crash bugs in the future.
    //memset(actor, 0, typeSize);
    
    ponyint_pool_free_size(typeSize, actor);
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
    size_t n = actor->q.num_messages;
    if (n < 0) {
        return 0;
    }
    return n;
}

pony_actor_t* ponyint_create_actor(pony_ctx_t* ctx)
{
    int32_t typeSize = sizeof(pony_actor_t);
    
    // allocate variable sized actors correctly
    pony_actor_t* actor = (pony_actor_t*)ponyint_pool_alloc_size(typeSize);
    
    memset(actor, 0, typeSize);
    
    static int32_t actorUID = 1;
    actor->uid = actorUID++;
    
    ponyint_messageq_init(&actor->q);
    
    return actor;
}

void ponyint_destroy_actor(pony_actor_t* actor)
{
    ponyint_actor_setpendingdestroy(actor);
    ponyint_actor_destroy(actor);
}

pony_msg_t* pony_alloc_msg(uint32_t index, uint32_t msgId)
{
    pony_msg_t* msg = (pony_msg_t*)ponyint_pool_alloc(index);
    msg->index = index;
    msg->msgId = msgId;
    return msg;
}

pony_msg_t* pony_alloc_msg_size(size_t size, uint32_t msgId)
{
    return pony_alloc_msg((uint32_t)ponyint_pool_index(size), msgId);
}

void pony_sendv(pony_ctx_t* ctx, pony_actor_t* to, pony_msg_t* first, pony_msg_t* last)
{
    // The function takes a prebuilt chain instead of varargs because the latter
    // is expensive and very hard to optimise.
    if(ponyint_actor_messageq_push(&to->q, first, last))
    {
        ponyint_sched_add(ctx, to);
    }
}

void pony_sendv_single(pony_ctx_t* ctx, pony_actor_t* to, pony_msg_t* first, pony_msg_t* last)
{
    // The function takes a prebuilt chain instead of varargs because the latter
    // is expensive and very hard to optimise.
    if(ponyint_actor_messageq_push_single(&to->q, first, last))
    {
        // if the receiving actor is currently not unscheduled AND it's not
        // muted, schedule it.
        ponyint_sched_add(ctx, to);
    }
}

void pony_chain(pony_msg_t* prev, pony_msg_t* next)
{
    assert(atomic_load_explicit(&prev->next, memory_order_relaxed) == NULL);
    atomic_store_explicit(&prev->next, next, memory_order_relaxed);
}

void pony_send(pony_ctx_t* ctx, pony_actor_t* to, uint32_t msgId)
{
    pony_msg_t* m = pony_alloc_msg(POOL_INDEX(sizeof(pony_msg_t)), msgId);
    pony_sendv(ctx, to, m, m);
}

void pony_send_block(pony_ctx_t* ctx, pony_actor_t* to, BlockCallback p)
{
    pony_msgb_t* m = (pony_msgb_t*)pony_alloc_msg(POOL_INDEX(sizeof(pony_msgb_t)), kMessageBlock);
    m->p = Block_copy_pony(p);
    pony_sendv(ctx, to, &m->msg, &m->msg);
}

void pony_send_fast_block(pony_ctx_t* ctx, pony_actor_t* to, void * args, FastBlockCallback p)
{
    pony_msgfb_t* m = (pony_msgfb_t*)pony_alloc_msg(POOL_INDEX(sizeof(pony_msgb_t)), kMessageFastBlock);
    m->p = p;
    m->a = args;
    pony_sendv(ctx, to, &m->msg, &m->msg);
}

void pony_sendp(pony_ctx_t* ctx, pony_actor_t* to, uint32_t msgId, void* p)
{
    pony_msgp_t* m = (pony_msgp_t*)pony_alloc_msg(POOL_INDEX(sizeof(pony_msgp_t)), msgId);
    m->p = p;
    
    pony_sendv(ctx, to, &m->msg, &m->msg);
}

void pony_sendpp(pony_ctx_t* ctx, pony_actor_t* to, uint32_t msgId, void* p1, void* p2)
{
    pony_msgpp_t* m = (pony_msgpp_t*)pony_alloc_msg(POOL_INDEX(sizeof(pony_msgpp_t)), msgId);
    m->p1 = p1;
    m->p2 = p2;
    
    pony_sendv(ctx, to, &m->msg, &m->msg);
}

void pony_sendi(pony_ctx_t* ctx, pony_actor_t* to, uint32_t msgId, intptr_t i)
{
    pony_msgi_t* m = (pony_msgi_t*)pony_alloc_msg(POOL_INDEX(sizeof(pony_msgi_t)), msgId);
    m->i = i;
    
    pony_sendv(ctx, to, &m->msg, &m->msg);
}
