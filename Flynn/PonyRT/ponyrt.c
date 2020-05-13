//
//  ponyrt.c
//  Flynn
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include <stdlib.h>

#include "ponyrt.h"

#include "messageq.h"
#include "scheduler.h"
#include "actor.h"
#include "cpu.h"

static bool pony_is_inited = false;

typedef struct {
    messageq_t q;
    uint64_t renderFrameNumber;
} PonyActor;

bool pony_startup() {
    if (pony_is_inited) { return true; }
    
    fprintf(stderr, "pony_startup()\n");
    ponyint_cpu_init();
    
    ponyint_sched_init();
    
    pony_is_inited = ponyint_sched_start();
    
    return pony_is_inited;
}

void pony_shutdown() {
    if (!pony_is_inited) { return; }
    
    fprintf(stderr, "pony_shutdown()\n");
    ponyint_sched_stop();
    
    pony_is_inited = false;
}

void * pony_actor_create() {
    return ponyint_create_actor(pony_ctx());
}

void pony_actor_dispatch(void * actor, void * context, PonyCallback callback) {
    pony_sendpp(pony_ctx(), actor, 1, context, callback);
}

int pony_actor_num_messages(void * actor) {
    return (int)ponyint_actor_num_messages(actor);
}

void pony_actor_destroy(void * actor) {
    ponyint_destroy_actor(actor);
}
