
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#include "ponyrt.h"
#include "messageq.h"
#include "memory.h"
#include "tsan.h"

static push_result_t messageq_push(messageq_t* q, pony_msg_t* first, pony_msg_t* last)
{
    atomic_fetch_add_explicit(&q->num_messages, 1, memory_order_relaxed);
    
    atomic_store_explicit(&last->next, NULL, memory_order_relaxed);
    
    // Without that fence, the store to last->next above could be reordered after
    // the exchange on the head and after the store to prev->next done by the
    // next push, which would result in the pop incorrectly seeing the queue as
    // empty.
    // Also synchronise with the pop on prev->next.
    atomic_thread_fence(memory_order_release);
    
    pony_msg_t* prev = atomic_exchange_explicit(&q->head, last,
                                                memory_order_relaxed);
    
    // This relaxed RMW joins the release sequence headed by the release CAS in
    // ponyint_messageq_markempty, which is what orders the thread that last
    // consumed from this queue before the thread now refilling it.
    // ThreadSanitizer does not implement release sequences: a relaxed RMW
    // neither inherits nor propagates a prior release in its model. Acquire
    // explicitly so the unschedule -> reschedule edge is visible.
    PONY_HB_AFTER(&q->head);
    
    // The queue is being torn down. Put the sentinel back exactly as we found
    // it -- the destroying thread relies on it staying set -- and hand the
    // message back to the caller to release. Appending here would write into a
    // queue that is about to be freed.
    if(((uintptr_t)prev & 2) != 0) {
        atomic_store_explicit(&q->head, prev, memory_order_relaxed);
        return kPushRefused;
    }
    
    bool was_empty = ((uintptr_t)prev & 1) != 0;
    prev = (pony_msg_t*)((uintptr_t)prev & ~(uintptr_t)1);
    
#ifdef PONY_TSAN_ENABLED
    // Double fence under ThreadSanitizer. The annotation needs prev in scope,
    // and TSAN does not model the standalone release fence above, so without
    // this the receiving thread appears to race on every message it pops.
    PONY_HB_BEFORE(&prev->next);
    atomic_thread_fence(memory_order_release);
#endif
    
    atomic_store_explicit(&prev->next, first, memory_order_relaxed);
    
    return was_empty ? kPushWasEmpty : kPushQueued;
}

void ponyint_messageq_init(messageq_t* q)
{
    pony_msg_t* stub = ponyint_pool_alloc(sizeof(pony_msg_t));
    stub->alloc_size = sizeof(pony_msg_t);
    atomic_store_explicit(&stub->next, NULL, memory_order_relaxed);
    
    atomic_store_explicit(&q->head, (pony_msg_t*)((uintptr_t)stub | 1),
                          memory_order_relaxed);
    q->tail = stub;
    
    atomic_store_explicit(&q->num_messages, 0, memory_order_relaxed);
}

void ponyint_messageq_destroy(messageq_t* q)
{
    // Release each remaining message's payload before its struct is reclaimed.
    // The drain used to just free the pony_msg_t, which leaked the unmanaged
    // retain on every queued ActorMessage -- and with it the Swift block and
    // everything the block captured. releaseFunc discards the payload without
    // running the behaviour.
    pony_msg_t* msg;
    while((msg = ponyint_thread_messageq_pop(q)) != NULL) {
        if(msg->msgId == kMessagePointer) {
            pony_msgfunc_t* m = (pony_msgfunc_t*)msg;
            if(m->releaseFunc != NULL) {
                m->releaseFunc(m->arg);
            }
        }
    }

    pony_msg_t* tail = q->tail;
    assert((((uintptr_t)atomic_load_explicit(&q->head, memory_order_relaxed) & ~(uintptr_t)3)) == (uintptr_t)tail);
    
    ponyint_pool_free(tail, tail->alloc_size);
    atomic_store_explicit(&q->head, NULL, memory_order_relaxed);
    q->tail = NULL;
    atomic_store_explicit(&q->num_messages, 0, memory_order_relaxed);
}

push_result_t ponyint_actor_messageq_push(messageq_t* q, pony_msg_t* first, pony_msg_t* last)
{
    return messageq_push(q, first, last);
}

pony_msg_t* ponyint_actor_messageq_pop(messageq_t* q)
{
    pony_msg_t* tail = q->tail;
    pony_msg_t* next = atomic_load_explicit(&tail->next, memory_order_relaxed);
    
    if(next != NULL)
    {
        q->tail = next;
        atomic_thread_fence(memory_order_acquire);
        PONY_HB_AFTER(&tail->next);
        ponyint_pool_free(tail, tail->alloc_size);
    }
    
    return next;
}

void ponyint_actor_messageq_pop_mark_done(messageq_t* q) {
    atomic_fetch_sub_explicit(&q->num_messages, 1, memory_order_relaxed);
}

pony_msg_t* ponyint_thread_messageq_pop(messageq_t* q)
{
    pony_msg_t* tail = q->tail;
    pony_msg_t* next = atomic_load_explicit(&tail->next, memory_order_relaxed);
    
    if(next != NULL)
    {
        q->tail = next;
        atomic_thread_fence(memory_order_acquire);
        PONY_HB_AFTER(&tail->next);
        ponyint_pool_free(tail, tail->alloc_size);
        
        atomic_fetch_sub_explicit(&q->num_messages, 1, memory_order_relaxed);
    }
    
    return next;
}

bool ponyint_messageq_markdestroyed(messageq_t* q)
{
    pony_msg_t* tail = q->tail;
    pony_msg_t* head = atomic_load_explicit(&q->head, memory_order_relaxed);
    
    // Already claimed by someone else.
    if(((uintptr_t)head & 2) != 0) { return false; }
    
    // Only a queue that is exactly drained and unmarked can be claimed.
    if(head != tail) { return false; }
    
    pony_msg_t* destroyed = (pony_msg_t*)((uintptr_t)head | 2);
    
    // Zero the count before the CAS: after it, the queue may be gone.
    atomic_store_explicit(&q->num_messages, 0, memory_order_relaxed);
    
    // This CAS is both the emptiness check and the claim. It sets bit 1 and
    // never bit 0, so the actor is never published: no push will report
    // kPushWasEmpty for it again, nothing can schedule it, and the caller
    // becomes its sole owner.
    return atomic_compare_exchange_strong_explicit(&q->head, &tail, destroyed,
                                                   memory_order_acq_rel,
                                                   memory_order_relaxed);
}

bool ponyint_messageq_markempty(messageq_t* q)
{
    pony_msg_t* tail = q->tail;
    pony_msg_t* head = atomic_load_explicit(&q->head, memory_order_relaxed);
    
    if(((uintptr_t)head & 2) != 0) {
        // Claimed for destruction; not ours to touch.
        return true;
    }
    
    if(((uintptr_t)head & 1) != 0) {
        // Already marked empty. The release CAS below is skipped on this path,
        // so publish this consumer's clock for TSAN explicitly; otherwise the
        // next producer to push here acquires a stale edge.
        // Already marked empty means the actor is ALREADY published, so
        // another scheduler may be running it and may have freed it. Nothing
        // here may write to the queue. PONY_HB_BEFORE only uses the address as
        // a key; it does not dereference it.
        PONY_HB_BEFORE(&q->head);
        return true;
    }
    
    if(head != tail)
        return false;
    
    head = (pony_msg_t*)((uintptr_t)head | 1);
    
    // Zero the count BEFORE the CAS. The CAS is the publication point: the
    // instant it succeeds a sender may schedule this actor onto another
    // scheduler, which may run it and free it. A store afterwards is a
    // use-after-free -- exactly the one ASan caught at messageq.c:142.
    atomic_store_explicit(&q->num_messages, 0, memory_order_relaxed);
    
    return atomic_compare_exchange_strong_explicit(&q->head, &tail, head,
                                                   memory_order_release, memory_order_relaxed);
}
