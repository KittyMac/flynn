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

// This header should contain only the minimum needed to communicate with Swift
typedef void (^BlockCallback)();
typedef void (^FastBlockCallback)(int, id, id, id, id, id, id, id, id, id, id);

// TODO: should we make this prettier for the swift side?
// Color ColorCreateWithCMYK(float c, float m, float y, float k) CF_SWIFT_NAME(Color.init(c:m:y:k:));

bool pony_startup(void);
void pony_shutdown(void);

void * pony_register_fast_block(FastBlockCallback callback);
void pony_unregister_fast_block(void * callback);

void * pony_actor_create();
void pony_actor_dispatch(void * actor, BlockCallback callback);
void pony_actor_fast_dispatch(void * actor, int numArgs, id arg0, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6, id arg7, id arg8, id arg9, void * callback);
int pony_actor_num_messages(void * actor);
void pony_actor_destroy(void * actor);

int pony_actors_load_balance(void * actorArray, int num_actors);
void pony_actors_wait(int min_msgs, void * actor, int num_actors);

#endif
