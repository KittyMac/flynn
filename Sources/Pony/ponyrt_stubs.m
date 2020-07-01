//
//  ponyrt.c
//  Flynn
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"
#if !defined(PLATFORM_SUPPORTS_PONYRT)

#include <stdlib.h>
#include <stdbool.h>

bool pony_startup() { }

void pony_shutdown() { }

int pony_core_count() { }

int pony_cpu_count() { }


void * pony_actor_create() { return NULL; }

void pony_actor_attach(void * actor, id swiftActor) { }

void pony_actor_setpriority(void * actor, int priority) { }

int pony_actor_getpriority(void * actor) { }

void pony_actor_setcoreAffinity(void * actor, int coreAffinity) { }

int pony_actor_getcoreAffinity(void * actor) { }

void pony_actor_yield(void * actor) { }

int pony_actors_load_balance(void * actorArray, int num_actors) { }

bool pony_actors_should_wait(int min_msgs, void * actorArray, int num_actors) { }

void pony_actors_wait(int min_msgs, void * actorArray, int num_actors) { }

void pony_actor_wait(int min_msgs, void * actor) { }

int pony_actor_num_messages(void * actor) { }

void pony_actor_destroy(void * actor) { }

#endif
