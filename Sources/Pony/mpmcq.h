//
//  mpmcq.h
//  Flynn
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#ifndef mpmcq_h
#define mpmcq_h

#include <stdio.h>
#include <stdint.h>
#include <stdalign.h>
#include "atomics.h"

typedef struct mpmcq_node_t mpmcq_node_t;

PONY_ABA_PROTECTED_PTR_DECLARE(mpmcq_node_t)

typedef struct mpmcq_t
{
    alignas(64) PONY_ATOMIC(mpmcq_node_t*) head;
    PONY_ATOMIC_ABA_PROTECTED_PTR(mpmcq_node_t) tail;
    PONY_ATOMIC(int64_t) num_messages;
} mpmcq_t;

void ponyint_mpmcq_init(mpmcq_t* q);

void ponyint_mpmcq_destroy(mpmcq_t* q);

void ponyint_mpmcq_push(mpmcq_t* q, void* data);

void ponyint_mpmcq_push_single(mpmcq_t* q, void* data);

void* ponyint_mpmcq_pop(mpmcq_t* q);

#endif /* mpmcq_h */
