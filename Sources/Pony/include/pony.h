
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#ifndef pony_h
#define pony_h

#include <stdbool.h>

typedef void (*CreateActorFunc)(const char * actorUUID, const char * actorType);
typedef void (*DestroyActorFunc)(const char * actorUUID);
typedef void (*MessageActorFunc)(const char * actorUUID, const char * behavior, void * payload, int payloadSize, int replySocketFD);
typedef void (*ReplyMessageFunc)(const char * actorUUID, void * payload, int payloadSize);


void pony_master(const char * address,
                 int port,
                 ReplyMessageFunc replyMessageFunc);
void pony_slave(const char * address,
                int port,
                CreateActorFunc createActorFunc,
                DestroyActorFunc destroyActorFunc,
                MessageActorFunc messageActorFunc);

void pony_remote_actor_send_message_to_slave(const char * actorUUID,
                                             const char * actorType,
                                             const char * behaviorType,
                                             int * slaveSocketFD,
                                             const void * bytes,
                                             int count);
void pony_remote_actor_send_message_to_master(int socketfd,
                                              const char * actorUUID,
                                              const void * bytes,
                                              int count);

void pony_remote_destroy_actor(const char * actorUUID, int * slaveSocketFD);

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
