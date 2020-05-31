//
//  messageq.h
//  Flynn
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//
// Note: This code is derivative of the Pony runtime; see README.md for more details

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

bool ponyint_actor_messageq_push(messageq_t* q, pony_msg_t* first, pony_msg_t* last);

pony_msg_t* ponyint_actor_messageq_pop(messageq_t* q);

void ponyint_actor_messageq_pop_mark_done(messageq_t* q);

bool ponyint_thread_messageq_push(messageq_t* q,pony_msg_t* first, pony_msg_t* last);

bool ponyint_thread_messageq_push_single(messageq_t* q,pony_msg_t* first, pony_msg_t* last);

pony_msg_t* ponyint_thread_messageq_pop(messageq_t* q);

bool ponyint_messageq_markempty(messageq_t* q);

#endif /* messageq_h */
