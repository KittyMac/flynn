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

void * pony_register_fast_block0(FastBlockCallback0 callback) { return objc_retain((__bridge void *)callback); }
void * pony_register_fast_block1(FastBlockCallback1 callback) { return objc_retain((__bridge void *)callback); }
void * pony_register_fast_block2(FastBlockCallback2 callback) { return objc_retain((__bridge void *)callback); }
void * pony_register_fast_block3(FastBlockCallback3 callback) { return objc_retain((__bridge void *)callback); }
void * pony_register_fast_block4(FastBlockCallback4 callback) { return objc_retain((__bridge void *)callback); }
void * pony_register_fast_block5(FastBlockCallback5 callback) { return objc_retain((__bridge void *)callback); }
void * pony_register_fast_block6(FastBlockCallback6 callback) { return objc_retain((__bridge void *)callback); }
void * pony_register_fast_block7(FastBlockCallback7 callback) { return objc_retain((__bridge void *)callback); }
void * pony_register_fast_block8(FastBlockCallback8 callback) { return objc_retain((__bridge void *)callback); }
void * pony_register_fast_block9(FastBlockCallback9 callback) { return objc_retain((__bridge void *)callback); }
void * pony_register_fast_block10(FastBlockCallback10 callback) { return objc_retain((__bridge void *)callback); }

void pony_unregister_fast_block0(void * p) { objc_autorelease(p); }
void pony_unregister_fast_block1(void * p) { objc_autorelease(p); }
void pony_unregister_fast_block2(void * p) { objc_autorelease(p); }
void pony_unregister_fast_block3(void * p) { objc_autorelease(p); }
void pony_unregister_fast_block4(void * p) { objc_autorelease(p); }
void pony_unregister_fast_block5(void * p) { objc_autorelease(p); }
void pony_unregister_fast_block6(void * p) { objc_autorelease(p); }
void pony_unregister_fast_block7(void * p) { objc_autorelease(p); }
void pony_unregister_fast_block8(void * p) { objc_autorelease(p); }
void pony_unregister_fast_block9(void * p) { objc_autorelease(p); }
void pony_unregister_fast_block10(void * p) { objc_autorelease(p); }

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

void pony_actor_fast_dispatch0(void * actor, void * callback) { pony_send_fast_block0(pony_ctx(), actor, (__bridge FastBlockCallback0)(callback)); }
void pony_actor_fast_dispatch1(void * actor, id arg0, void * callback) {
    objc_retain(arg0);
    pony_send_fast_block1(pony_ctx(), actor, arg0, (__bridge FastBlockCallback1)(callback));
}
void pony_actor_fast_dispatch2(void * actor, id arg0, id arg1, void * callback) {
    objc_retain(arg0); objc_retain(arg1);
    pony_send_fast_block2(pony_ctx(), actor, arg0, arg1, (__bridge FastBlockCallback2)(callback));
}
void pony_actor_fast_dispatch3(void * actor, id arg0, id arg1, id arg2, void * callback) {
    objc_retain(arg0); objc_retain(arg1); objc_retain(arg2);
    pony_send_fast_block3(pony_ctx(), actor, arg0, arg1, arg2, (__bridge FastBlockCallback3)(callback));
}
void pony_actor_fast_dispatch4(void * actor, id arg0, id arg1, id arg2, id arg3, void * callback) {
    objc_retain(arg0); objc_retain(arg1); objc_retain(arg2); objc_retain(arg3);
    pony_send_fast_block4(pony_ctx(), actor, arg0, arg1, arg2, arg3, (__bridge FastBlockCallback4)(callback));
}
void pony_actor_fast_dispatch5(void * actor, id arg0, id arg1, id arg2, id arg3, id arg4, void * callback) {
    objc_retain(arg0); objc_retain(arg1); objc_retain(arg2); objc_retain(arg3); objc_retain(arg4);
    pony_send_fast_block5(pony_ctx(), actor, arg0, arg1, arg2, arg3, arg4, (__bridge FastBlockCallback5)(callback));
}
void pony_actor_fast_dispatch6(void * actor, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5, void * callback) {
    objc_retain(arg0); objc_retain(arg1); objc_retain(arg2); objc_retain(arg3); objc_retain(arg4); objc_retain(arg5);
    pony_send_fast_block6(pony_ctx(), actor, arg0, arg1, arg2, arg3, arg4, arg5, (__bridge FastBlockCallback6)(callback));
}
void pony_actor_fast_dispatch7(void * actor, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6, void * callback) {
    objc_retain(arg0); objc_retain(arg1); objc_retain(arg2); objc_retain(arg3); objc_retain(arg4); objc_retain(arg5); objc_retain(arg6);
    pony_send_fast_block7(pony_ctx(), actor, arg0, arg1, arg2, arg3, arg4, arg5, arg6, (__bridge FastBlockCallback7)(callback));
}
void pony_actor_fast_dispatch8(void * actor, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6, id arg7, void * callback) {
    objc_retain(arg0); objc_retain(arg1); objc_retain(arg2); objc_retain(arg3); objc_retain(arg4); objc_retain(arg5); objc_retain(arg6); objc_retain(arg7);
    pony_send_fast_block8(pony_ctx(), actor, arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, (__bridge FastBlockCallback8)(callback));
}
void pony_actor_fast_dispatch9(void * actor, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6, id arg7, id arg8, void * callback) {
    objc_retain(arg0); objc_retain(arg1); objc_retain(arg2); objc_retain(arg3); objc_retain(arg4); objc_retain(arg5); objc_retain(arg6); objc_retain(arg7); objc_retain(arg8);
    pony_send_fast_block9(pony_ctx(), actor, arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, (__bridge FastBlockCallback9)(callback));
}
void pony_actor_fast_dispatch10(void * actor, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6, id arg7, id arg8, id arg9, void * callback) {
    objc_retain(arg0); objc_retain(arg1); objc_retain(arg2); objc_retain(arg3); objc_retain(arg4); objc_retain(arg5); objc_retain(arg6); objc_retain(arg7); objc_retain(arg8); objc_retain(arg9);
    pony_send_fast_block10(pony_ctx(), actor, arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, (__bridge FastBlockCallback10)(callback));
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
