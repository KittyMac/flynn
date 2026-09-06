
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#ifndef messageq_h
#define messageq_h

#include "atomics.h"
#include "ponyrt.h"

typedef struct messageq_t
{
    PONY_ATOMIC(pony_msg_t*) head;
    pony_msg_t* tail;
    PONY_ATOMIC(int32_t) num_messages;
} messageq_t;

#define UNKNOWN_SCHEDULER -1

void ponyint_messageq_init(messageq_t* q);

void ponyint_messageq_destroy(messageq_t* q);

// Result of a push. The queue head carries two sentinel bits:
//   bit 0 -- empty: the actor is unscheduled, the pusher owns rescheduling it.
//   bit 1 -- destroyed: the queue is being torn down; the push is refused and
//            the caller owns releasing the message it was carrying.
typedef enum {
    kPushQueued = 0,    // appended to a live, already-scheduled queue
    kPushWasEmpty = 1,  // appended; caller must ponyint_sched_add()
    kPushRefused = 2    // NOT appended; caller must release the message
} push_result_t;

push_result_t ponyint_actor_messageq_push(messageq_t* q, pony_msg_t* first, pony_msg_t* last);

// Claims the queue for destruction. Succeeds only if the queue is exactly
// drained and nobody else has claimed it. Unlike markempty() this never sets
// the empty bit, so it never publishes the actor -- once it succeeds no sender
// can schedule the actor again and the caller is its sole owner.
bool ponyint_messageq_markdestroyed(messageq_t* q);

pony_msg_t* ponyint_actor_messageq_pop(messageq_t* q);

void ponyint_actor_messageq_pop_mark_done(messageq_t* q);

pony_msg_t* ponyint_thread_messageq_pop(messageq_t* q);

bool ponyint_messageq_markempty(messageq_t* q);

#endif /* messageq_h */
