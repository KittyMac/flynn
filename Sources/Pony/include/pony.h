
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#ifndef pony_h
#define pony_h

#include <stdbool.h>

void pony_master(const char * address, int port);
void pony_slave(const char * address, int port);

void pony_remote_actor_send_message_to_slave(const char * actorUUID, const char * actorType, int * slaveID, const void * bytes, int count);
void pony_remote_actor_send_message_to_master(const char * actorUUID, const void * bytes, int count);

bool pony_startup(void);
void pony_shutdown(void);

int pony_core_count();
int pony_e_core_count();
int pony_p_core_count();
bool pony_core_affinity_enabled();

void * pony_actor_create();

void pony_actor_send_message(void * actor, void * argumentPtr, void (*handleMessageFunc)(void * message));

void pony_actor_setpriority(void * actor, int priority);
int pony_actor_getpriority(void * actor);

void pony_actor_setbatchSize(void * actor, int batchSize);
int pony_actor_getbatchSize(void * actor);

void pony_actor_setcoreAffinity(void * actor, int coreAffinity);
int pony_actor_getcoreAffinity(void * actor);

void pony_actor_yield(void * actor);

int pony_actor_num_messages(void * actor);
void pony_actor_destroy(void * actor);

int pony_actors_load_balance(void * actorArray, int num_actors);

bool pony_actors_should_wait(int min_msgs, void * actorArray, int num_actors);
void pony_actors_wait(int min_msgs, void * actor, int num_actors);
void pony_actor_wait(int min_msgs, void * actor);

int pony_max_memory();

#endif
