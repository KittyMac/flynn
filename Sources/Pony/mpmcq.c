
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#define PONY_WANT_ATOMIC_DEFS

#include "mpmcq.h"
#include "memory.h"
#include "cpu.h"
#include <stdio.h>

typedef struct mpmcq_node_t mpmcq_node_t;

struct mpmcq_node_t
{
    PONY_ATOMIC(mpmcq_node_t*) next;
    PONY_ATOMIC(void*) data;
};

static mpmcq_node_t* node_alloc(void* data)
{
    mpmcq_node_t* node = ponyint_pool_alloc(sizeof(mpmcq_node_t));
    atomic_store_explicit(&node->next, NULL, memory_order_relaxed);
    atomic_store_explicit(&node->data, data, memory_order_relaxed);
    return node;
}

static void node_free(mpmcq_node_t* node)
{
    ponyint_pool_free(node, sizeof(mpmcq_node_t));
}

void ponyint_mpmcq_init(mpmcq_t* q)
{
    mpmcq_node_t* node = node_alloc(NULL);
    
    atomic_store_explicit(&q->head, node, memory_order_relaxed);
    q->tail.object = node;
    q->tail.counter = 0;
    
    atomic_store_explicit(&q->num_messages, 0, memory_order_relaxed);
}

void ponyint_mpmcq_destroy(mpmcq_t* q)
{
    atomic_store_explicit(&q->head, NULL, memory_order_relaxed);
    node_free(q->tail.object);
    q->tail.object = NULL;
    atomic_store_explicit(&q->num_messages, 0, memory_order_relaxed);
}

void ponyint_mpmcq_push(mpmcq_t* q, void* data)
{
    mpmcq_node_t* node = node_alloc(data);
    
    atomic_fetch_add_explicit(&q->num_messages, 1, memory_order_relaxed);
    
    // Without that fence, the store to node->next in node_alloc could be
    // reordered after the exchange on the head and after the store to prev->next
    // done by the next push, which would result in the pop incorrectly seeing
    // the queue as empty.
    // Also synchronise with the pop on prev->next.
    atomic_thread_fence(memory_order_release);
    
    mpmcq_node_t* prev = atomic_exchange_explicit(&q->head, node, memory_order_relaxed);
    
    atomic_store_explicit(&prev->next, node, memory_order_relaxed);
}

void ponyint_mpmcq_push_single(mpmcq_t* q, void* data)
{
    mpmcq_node_t* node = node_alloc(data);
    
    atomic_fetch_add_explicit(&q->num_messages, 1, memory_order_relaxed);
    
    // If we have a single producer, the swap of the head need not be atomic RMW.
    mpmcq_node_t* prev = atomic_load_explicit(&q->head, memory_order_relaxed);
    atomic_store_explicit(&q->head, node, memory_order_relaxed);
    
    // If we have a single producer, the fence can be replaced with a store
    // release on prev->next.
    atomic_store_explicit(&prev->next, node, memory_order_release);
}

void* ponyint_mpmcq_pop(mpmcq_t* q)
{
    PONY_ABA_PROTECTED_PTR(mpmcq_node_t) cmp;
    PONY_ABA_PROTECTED_PTR(mpmcq_node_t) xchg;
    mpmcq_node_t* tail;
    // Load the tail non-atomically. If object and counter are out of sync, we'll
    // do an additional CAS iteration which isn't less efficient than doing an
    // atomic initial load.
    cmp.object = q->tail.object;
    cmp.counter = q->tail.counter;
    
    mpmcq_node_t* next;
    
    do
    {
        tail = cmp.object;
        // Get the next node rather than the tail. The tail is either a stub or has
        // already been consumed.
        if(tail == NULL)
            return NULL;
        
        // Note: Xcode address sanitizer fails on this call. unclear whether this is
        // an actual problem with this fencing mechanism or a red herring
        next = atomic_load_explicit(&tail->next, memory_order_relaxed);
        
        if(next == NULL)
            return NULL;
        
        xchg.object = next;
        xchg.counter = cmp.counter + 1;
        
        // NOTE: unlike the original ponyrt, we only call into ponyint_mpmcq_pop() when blocked by mutexes
        // therefore, there will be no thread contention in the execution of this function and we don't
        // need to bigatomic_compare_exchange_weak_explicit();
        //if (q->tail.object == cmp.object) {
        //    q->tail = xchg;
        //    continue;
        //}
        //break;
    }while(!bigatomic_compare_exchange_weak_explicit(&q->tail, &cmp, xchg,
                                                     memory_order_acq_rel, memory_order_acquire));
    
    // Synchronise on tail->next to ensure we see the write to next->data from
    // the push. Also synchronise on next->data (see comment below).
    // This is a standalone fence instead of a synchronised compare_exchange
    // operation because the latter would result in unnecessary synchronisation
    // on each loop iteration.
    atomic_thread_fence(memory_order_acq_rel);
    
    void* data = atomic_load_explicit(&next->data, memory_order_acquire);
    
    // Since we will be freeing the old tail, we need to be sure no other
    // consumer is still reading the old tail. To do this, we set the data
    // pointer of our new tail to NULL, and we wait until the data pointer of
    // the old tail is NULL.
    // We synchronised on next->data to make sure all memory writes we've done
    // will be visible from the thread that will free our tail when it starts
    // freeing it.
    atomic_store_explicit(&next->data, NULL, memory_order_release);
    
    while(atomic_load_explicit(&tail->data, memory_order_acquire) != NULL)
        ponyint_cpu_relax();
    
    // Synchronise on tail->data to make sure we see every previous write to the
    // old tail before freeing it. This is a standalone fence to avoid
    // unnecessary synchronisation on each loop iteration.
    atomic_thread_fence(memory_order_acquire);
    
    node_free(tail);
    
    if (data != NULL) {
        atomic_fetch_sub_explicit(&q->num_messages, 1, memory_order_relaxed);
    }
    
    return data;
}
