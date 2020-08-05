//
//  pony.h
//  Flynn
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#ifndef pony_h
#define pony_h

#include <stdbool.h>

bool pony_startup(void);
void pony_shutdown(void);

int pony_core_count();

void * pony_actor_create();
void pony_actor_attach_swift_actor(void * actor, void * swiftActor);

void pony_actor_send_message(void * actor, void * argumentPtr, void (*handleMessageFunc)(void * message));

void pony_actor_setpriority(void * actor, int priority);
int pony_actor_getpriority(void * actor);

void pony_actor_setcoreAffinity(void * actor, int coreAffinity);
int pony_actor_getcoreAffinity(void * actor);

void pony_actor_yield(void * actor);

int pony_actor_num_messages(void * actor);
void pony_actor_destroy(void * actor);

int pony_actors_load_balance(void * actorArray, int num_actors);

bool pony_actors_should_wait(int min_msgs, void * actorArray, int num_actors);
void pony_actors_wait(int min_msgs, void * actor, int num_actors);
void pony_actor_wait(int min_msgs, void * actor);

#endif
