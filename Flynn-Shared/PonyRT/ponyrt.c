//
//  ponyrt.c
//  Flynn
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include <stdlib.h>
#include <CoreFoundation/CoreFoundation.h>

#include "ponyrt.h"

#include "messageq.h"
#include "scheduler.h"
#include "actor.h"
#include "cpu.h"
#include "alloc.h"
#include "pool.h"

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

void pony_actor_dispatch(void * actor, BlockCallback callback) {
    pony_send_block(pony_ctx(), actor, callback);
}

void pony_actor_fast_dispatch(void * actor, void * argsPtr, FastBlockCallback callback) {
    objc_retain(argsPtr);
    pony_send_fast_block(pony_ctx(), actor, argsPtr, callback);
}

int pony_actors_load_balance(void * actorArray, int num_actors) {
    pony_actor_t ** actorsPtr = (pony_actor_t**)actorArray;
    pony_actor_t * minActor = *actorsPtr;
    int minIdx = 0;
    for (int i = 0; i < num_actors; i++) {
        if(actorsPtr[i]->q.num_messages < minActor->q.num_messages) {
            minActor = actorsPtr[i];
            minIdx = i;
            if (minActor->q.num_messages == 0) {
                return minIdx;
            }
        }
    }
    return minIdx;
}

void pony_actors_wait(int min_msgs, void * actorArray, int num_actors) {
    // we hard wait until all actors we have been given have no messages waiting
    pony_actor_t ** actorsPtr = (pony_actor_t**)actorArray;
    int scaling_sleep = 10;
    int max_scaling_sleep = 500;
    while (true) {
        int32_t n = 0;
        for (int i = 0; i < num_actors; i++) {
            n += actorsPtr[i]->q.num_messages;
        }
        if (n <= min_msgs) {
            break;
        }
        ponyint_cpu_sleep(scaling_sleep);
        scaling_sleep += 1;
        if (scaling_sleep > max_scaling_sleep) {
            scaling_sleep = max_scaling_sleep;
        }
    }
}

int pony_actor_num_messages(void * actor) {
    return (int)ponyint_actor_num_messages(actor);
}

void pony_actor_destroy(void * actor) {
    ponyint_destroy_actor(actor);
}
