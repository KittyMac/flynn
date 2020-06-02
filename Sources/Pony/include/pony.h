//
//  pony.h
//  Flynn
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//
// Note: This code is derivative of the Pony runtime; see README.md for more details

#ifndef pony_h
#define pony_h

#include <stdbool.h>

// This header should contain only the minimum needed to communicate with Swift
typedef void (^BlockCallback)();
typedef void (^FastBlockCallback0)();
typedef void (^FastBlockCallback1)(id);
typedef void (^FastBlockCallback2)(id, id);
typedef void (^FastBlockCallback3)(id, id, id);
typedef void (^FastBlockCallback4)(id, id, id, id);
typedef void (^FastBlockCallback5)(id, id, id, id, id);
typedef void (^FastBlockCallback6)(id, id, id, id, id, id);
typedef void (^FastBlockCallback7)(id, id, id, id, id, id, id);
typedef void (^FastBlockCallback8)(id, id, id, id, id, id, id, id);
typedef void (^FastBlockCallback9)(id, id, id, id, id, id, id, id, id);
typedef void (^FastBlockCallback10)(id, id, id, id, id, id, id, id, id, id);

// TODO: should we make this prettier for the swift side?
// Color ColorCreateWithCMYK(float c, float m, float y, float k) CF_SWIFT_NAME(Color.init(c:m:y:k:));

bool pony_startup(void);
void pony_shutdown(void);
int pony_cpu_count();

void * pony_register_fast_block0(FastBlockCallback0 callback);
void * pony_register_fast_block1(FastBlockCallback1 callback);
void * pony_register_fast_block2(FastBlockCallback2 callback);
void * pony_register_fast_block3(FastBlockCallback3 callback);
void * pony_register_fast_block4(FastBlockCallback4 callback);
void * pony_register_fast_block5(FastBlockCallback5 callback);
void * pony_register_fast_block6(FastBlockCallback6 callback);
void * pony_register_fast_block7(FastBlockCallback7 callback);
void * pony_register_fast_block8(FastBlockCallback8 callback);
void * pony_register_fast_block9(FastBlockCallback9 callback);
void * pony_register_fast_block10(FastBlockCallback10 callback);

void pony_unregister_fast_block(void * callback);

void * pony_actor_create();
void pony_actor_dispatch(void * actor, BlockCallback callback);

void pony_actor_fast_dispatch0(void * actor, void * callback);
void pony_actor_fast_dispatch1(void * actor, id arg0, void * callback);
void pony_actor_fast_dispatch2(void * actor, id arg0, id arg1, void * callback);
void pony_actor_fast_dispatch3(void * actor, id arg0, id arg1, id arg2, void * callback);
void pony_actor_fast_dispatch4(void * actor, id arg0, id arg1, id arg2, id arg3, void * callback);
void pony_actor_fast_dispatch5(void * actor, id arg0, id arg1, id arg2, id arg3, id arg4, void * callback);
void pony_actor_fast_dispatch6(void * actor, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5, void * callback);
void pony_actor_fast_dispatch7(void * actor, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6, void * callback);
void pony_actor_fast_dispatch8(void * actor, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6, id arg7, void * callback);
void pony_actor_fast_dispatch9(void * actor, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6, id arg7, id arg8, void * callback);
void pony_actor_fast_dispatch10(void * actor, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6, id arg7, id arg8, id arg9, void * callback);

void pony_actor_yield(void * actor);

int pony_actor_num_messages(void * actor);
void pony_actor_destroy(void * actor);

int pony_actors_load_balance(void * actorArray, int num_actors);

bool pony_actors_should_wait(int min_msgs, void * actorArray, int num_actors);
void pony_actors_wait(int min_msgs, void * actor, int num_actors);
void pony_actor_wait(int min_msgs, void * actor);

#endif
