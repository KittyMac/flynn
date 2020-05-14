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
typedef void (^PonyCallback)();

bool pony_startup(void);
void pony_shutdown(void);

void * pony_actor_create();
void pony_actor_dispatch(void * actor, PonyCallback callback);
int pony_actor_num_messages(void * actor);
void pony_actor_destroy(void * actor);

int pony_actors_load_balance(void * actorArray, int num_actors);
void pony_actors_wait(int min_msgs, void * actor, int num_actors);

#endif
