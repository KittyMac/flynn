//
//  actor.c
//  Flynn
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//
// Note: This code is derivative of the Pony runtime; see README.md for more details

#define PONY_WANT_ATOMIC_DEFS

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
bool ponyint_actor_run(pony_ctx_t* ctx, pony_actor_t* actor, int max_msgs)
{
    pony_msg_t* msg;
    int n = 0;
    
    while((msg = (pony_msg_t *)ponyint_actor_messageq_pop(&actor->q)) != NULL) {
        
        switch(msg->msgId) {
            case kMessageFastBlock0: {
                pony_msgfb0_t * m = (pony_msgfb0_t *)msg;
                m->p();
                objc_autorelease(m->p);
                objc_autorelease(actor->swiftActor);
            } break;
            
            case kMessageFastBlock1: {
                pony_msgfb1_t * m = (pony_msgfb1_t *)msg;
                m->p(m->a0);
                objc_autorelease(m->p);
                objc_autorelease(actor->swiftActor);
                objc_autorelease(m->a0);
            } break;
            
            case kMessageFastBlock2: {
                pony_msgfb2_t * m = (pony_msgfb2_t *)msg;
                m->p(m->a0, m->a1);
                objc_autorelease(m->p);
                objc_autorelease(actor->swiftActor);
                objc_autorelease(m->a0); objc_autorelease(m->a1);
            } break;
            
            case kMessageFastBlock3: {
                pony_msgfb3_t * m = (pony_msgfb3_t *)msg;
                m->p(m->a0, m->a1, m->a2);
                objc_autorelease(m->p);
                objc_autorelease(actor->swiftActor);
                objc_autorelease(m->a0); objc_autorelease(m->a1); objc_autorelease(m->a2);
            } break;
            
            case kMessageFastBlock4: {
                pony_msgfb4_t * m = (pony_msgfb4_t *)msg;
                m->p(m->a0, m->a1, m->a2, m->a3);
                objc_autorelease(m->p);
                objc_autorelease(actor->swiftActor);
                objc_autorelease(m->a0); objc_autorelease(m->a1); objc_autorelease(m->a2); objc_autorelease(m->a3);
            } break;
            
            case kMessageFastBlock5: {
                pony_msgfb5_t * m = (pony_msgfb5_t *)msg;
                m->p(m->a0, m->a1, m->a2, m->a3, m->a4);
                objc_autorelease(m->p);
                objc_autorelease(actor->swiftActor);
                objc_autorelease(m->a0); objc_autorelease(m->a1); objc_autorelease(m->a2); objc_autorelease(m->a3); objc_autorelease(m->a4);
            } break;
            
            case kMessageFastBlock6: {
                pony_msgfb6_t * m = (pony_msgfb6_t *)msg;
                m->p(m->a0, m->a1, m->a2, m->a3, m->a4, m->a5);
                objc_autorelease(m->p);
                objc_autorelease(actor->swiftActor);
                objc_autorelease(m->a0); objc_autorelease(m->a1); objc_autorelease(m->a2); objc_autorelease(m->a3); objc_autorelease(m->a4); objc_autorelease(m->a5);
            } break;
            
            case kMessageFastBlock7: {
                pony_msgfb7_t * m = (pony_msgfb7_t *)msg;
                m->p(m->a0, m->a1, m->a2, m->a3, m->a4, m->a5, m->a6);
                objc_autorelease(m->p);
                objc_autorelease(actor->swiftActor);
                objc_autorelease(m->a0); objc_autorelease(m->a1); objc_autorelease(m->a2); objc_autorelease(m->a3); objc_autorelease(m->a4); objc_autorelease(m->a5); objc_autorelease(m->a6);
            } break;
            
            case kMessageFastBlock8: {
                pony_msgfb8_t * m = (pony_msgfb8_t *)msg;
                m->p(m->a0, m->a1, m->a2, m->a3, m->a4, m->a5, m->a6, m->a7);
                objc_autorelease(m->p);
                objc_autorelease(actor->swiftActor);
                objc_autorelease(m->a0); objc_autorelease(m->a1); objc_autorelease(m->a2); objc_autorelease(m->a3); objc_autorelease(m->a4); objc_autorelease(m->a5); objc_autorelease(m->a6); objc_autorelease(m->a7);
            } break;
            
            case kMessageFastBlock9: {
                pony_msgfb9_t * m = (pony_msgfb9_t *)msg;
                m->p(m->a0, m->a1, m->a2, m->a3, m->a4, m->a5, m->a6, m->a7, m->a8);
                objc_autorelease(m->p);
                objc_autorelease(actor->swiftActor);
                objc_autorelease(m->a0); objc_autorelease(m->a1); objc_autorelease(m->a2); objc_autorelease(m->a3); objc_autorelease(m->a4); objc_autorelease(m->a5); objc_autorelease(m->a6); objc_autorelease(m->a7); objc_autorelease(m->a8);
            } break;
                
            case kMessageFastBlock10: {
                pony_msgfb10_t * m = (pony_msgfb10_t *)msg;
                m->p(m->a0, m->a1, m->a2, m->a3, m->a4, m->a5, m->a6, m->a7, m->a8, m->a9);
                objc_autorelease(m->p);
                objc_autorelease(actor->swiftActor);
                objc_autorelease(m->a0); objc_autorelease(m->a1); objc_autorelease(m->a2); objc_autorelease(m->a3); objc_autorelease(m->a4); objc_autorelease(m->a5); objc_autorelease(m->a6); objc_autorelease(m->a7); objc_autorelease(m->a8); objc_autorelease(m->a9);
            } break;
        }
        
        ponyint_actor_messageq_pop_mark_done(&actor->q);
        
        n++;
        if (n > max_msgs || actor->yield) {
            break;
        }
    }
    
    // Return true (i.e. reschedule immediately) if our queue isn't empty.
    return !ponyint_messageq_markempty(&actor->q);
}

int32_t ponyint_actor_getpriority(pony_actor_t* actor) {
    return actor->priority;
}

void ponyint_actor_setpriority(pony_actor_t* actor, int32_t priority)
{
    actor->priority = priority;
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

void pony_send(pony_ctx_t* ctx, pony_actor_t* to, uint32_t msgId)
{
    pony_msg_t* m = pony_alloc_msg(POOL_INDEX(sizeof(pony_msg_t)), msgId);
    pony_sendv(ctx, to, m, m);
}



void pony_send_fast_block0(pony_ctx_t* ctx, pony_actor_t* to, FastBlockCallback0 p)
{
    pony_msgfb0_t* m = (pony_msgfb0_t*)pony_alloc_msg(POOL_INDEX(sizeof(pony_msgfb0_t)), kMessageFastBlock0);
    m->p = p;
    objc_retain(to->swiftActor);
    pony_sendv(ctx, to, &m->msg, &m->msg);
}

void pony_send_fast_block1(pony_ctx_t* ctx, pony_actor_t* to, id arg0, FastBlockCallback1 p)
{
    pony_msgfb1_t* m = (pony_msgfb1_t*)pony_alloc_msg(POOL_INDEX(sizeof(pony_msgfb1_t)), kMessageFastBlock1);
    m->p = p; m->a0 = arg0;
    objc_retain(to->swiftActor);
    pony_sendv(ctx, to, &m->msg, &m->msg);
}

void pony_send_fast_block2(pony_ctx_t* ctx, pony_actor_t* to, id arg0, id arg1, FastBlockCallback2 p)
{
    pony_msgfb2_t* m = (pony_msgfb2_t*)pony_alloc_msg(POOL_INDEX(sizeof(pony_msgfb2_t)), kMessageFastBlock2);
    m->p = p; m->a0 = arg0; m->a1 = arg1;
    objc_retain(to->swiftActor);
    pony_sendv(ctx, to, &m->msg, &m->msg);
}

void pony_send_fast_block3(pony_ctx_t* ctx, pony_actor_t* to, id arg0, id arg1, id arg2, FastBlockCallback3 p)
{
    pony_msgfb3_t* m = (pony_msgfb3_t*)pony_alloc_msg(POOL_INDEX(sizeof(pony_msgfb3_t)), kMessageFastBlock3);
    m->p = p; m->a0 = arg0; m->a1 = arg1; m->a2 = arg2;
    objc_retain(to->swiftActor);
    pony_sendv(ctx, to, &m->msg, &m->msg);
}

void pony_send_fast_block4(pony_ctx_t* ctx, pony_actor_t* to, id arg0, id arg1, id arg2, id arg3, FastBlockCallback4 p)
{
    pony_msgfb4_t* m = (pony_msgfb4_t*)pony_alloc_msg(POOL_INDEX(sizeof(pony_msgfb4_t)), kMessageFastBlock4);
    m->p = p; m->a0 = arg0; m->a1 = arg1; m->a2 = arg2; m->a3 = arg3;
    objc_retain(to->swiftActor);
    pony_sendv(ctx, to, &m->msg, &m->msg);
}

void pony_send_fast_block5(pony_ctx_t* ctx, pony_actor_t* to, id arg0, id arg1, id arg2, id arg3, id arg4, FastBlockCallback5 p)
{
    pony_msgfb5_t* m = (pony_msgfb5_t*)pony_alloc_msg(POOL_INDEX(sizeof(pony_msgfb5_t)), kMessageFastBlock5);
    m->p = p; m->a0 = arg0; m->a1 = arg1; m->a2 = arg2; m->a3 = arg3; m->a4 = arg4;
    objc_retain(to->swiftActor);
    pony_sendv(ctx, to, &m->msg, &m->msg);
}

void pony_send_fast_block6(pony_ctx_t* ctx, pony_actor_t* to, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5, FastBlockCallback6 p)
{
    pony_msgfb6_t* m = (pony_msgfb6_t*)pony_alloc_msg(POOL_INDEX(sizeof(pony_msgfb6_t)), kMessageFastBlock6);
    m->p = p; m->a0 = arg0; m->a1 = arg1; m->a2 = arg2; m->a3 = arg3; m->a4 = arg4; m->a5 = arg5;
    objc_retain(to->swiftActor);
    pony_sendv(ctx, to, &m->msg, &m->msg);
}

void pony_send_fast_block7(pony_ctx_t* ctx, pony_actor_t* to, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6, FastBlockCallback7 p)
{
    pony_msgfb7_t* m = (pony_msgfb7_t*)pony_alloc_msg(POOL_INDEX(sizeof(pony_msgfb7_t)), kMessageFastBlock7);
    m->p = p; m->a0 = arg0; m->a1 = arg1; m->a2 = arg2; m->a3 = arg3; m->a4 = arg4; m->a5 = arg5; m->a6 = arg6;
    objc_retain(to->swiftActor);
    pony_sendv(ctx, to, &m->msg, &m->msg);
}

void pony_send_fast_block8(pony_ctx_t* ctx, pony_actor_t* to, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6, id arg7, FastBlockCallback8 p)
{
    pony_msgfb8_t* m = (pony_msgfb8_t*)pony_alloc_msg(POOL_INDEX(sizeof(pony_msgfb8_t)), kMessageFastBlock8);
    m->p = p; m->a0 = arg0; m->a1 = arg1; m->a2 = arg2; m->a3 = arg3; m->a4 = arg4; m->a5 = arg5; m->a6 = arg6; m->a7 = arg7;
    objc_retain(to->swiftActor);
    pony_sendv(ctx, to, &m->msg, &m->msg);
}

void pony_send_fast_block9(pony_ctx_t* ctx, pony_actor_t* to, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6, id arg7, id arg8, FastBlockCallback9 p)
{
    pony_msgfb9_t* m = (pony_msgfb9_t*)pony_alloc_msg(POOL_INDEX(sizeof(pony_msgfb9_t)), kMessageFastBlock9);
    m->p = p; m->a0 = arg0; m->a1 = arg1; m->a2 = arg2; m->a3 = arg3; m->a4 = arg4; m->a5 = arg5; m->a6 = arg6; m->a7 = arg7; m->a8 = arg8;
    objc_retain(to->swiftActor);
    pony_sendv(ctx, to, &m->msg, &m->msg);
}

void pony_send_fast_block10(pony_ctx_t* ctx, pony_actor_t* to, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6, id arg7, id arg8, id arg9, FastBlockCallback10 p)
{
    pony_msgfb10_t* m = (pony_msgfb10_t*)pony_alloc_msg(POOL_INDEX(sizeof(pony_msgfb10_t)), kMessageFastBlock10);
    m->p = p; m->a0 = arg0; m->a1 = arg1; m->a2 = arg2; m->a3 = arg3; m->a4 = arg4; m->a5 = arg5; m->a6 = arg6; m->a7 = arg7; m->a8 = arg8; m->a9 = arg9;
    objc_retain(to->swiftActor);
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
