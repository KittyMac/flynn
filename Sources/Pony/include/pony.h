
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#ifndef pony_h
#define pony_h

#include <stdbool.h>
#include <sys/types.h>
#include <stdint.h>

typedef void (*RegisterWithRootFunc)(const char * registrationString, int socketFD);
typedef void (*NodeDisconnectedFunc)(int socketFD);
typedef void (*CreateActorFunc)(const char * actorUUID, const char * actorType, bool shouldBeProxy, int socketFD);
typedef void (*DestroyActorFunc)(const char * actorUUID);
typedef void (*MessageActorFunc)(const char * actorUUID, const char * behavior, void * payload, int payloadSize, int messageID, int replySocketFD);
typedef void (*RegisterActorsOnRootFunc)(int replySocketFD);

typedef void (*ReplyMessageFunc)(int messageID, void * payload, int payloadSize);

void pony_root(const char * address,
               int port,
               RegisterWithRootFunc registerWithRootPtr,
               CreateActorFunc createActorFunc,
               ReplyMessageFunc replyMessageFunc,
               NodeDisconnectedFunc nodeDisconnected);
void pony_node(const char * address,
               int port,
               bool automaticReconnect,
               CreateActorFunc createActorFunc,
               DestroyActorFunc destroyActorFunc,
               MessageActorFunc messageActorFunc,
               RegisterActorsOnRootFunc registerActorsOnRootFunc);

int pony_remote_nodes_count();
int pony_remote_core_count();
int pony_remote_core_count_by_socket(int socketfd);

int pony_next_messageId();

int pony_root_num_active_remotes();

int pony_root_send_actor_message_to_node(const char * actorUUID,
                                         const char * actorType,
                                         const char * behaviorType,
                                         bool actorNeedsCreated,
                                         int nodeSocketFD,
                                         const void * bytes,
                                         int count);
void pony_node_send_actor_message_to_root(int socketfd,
                                          int messageID,
                                          const void * bytes,
                                          int count);
void pony_register_node_to_root(int socketfd,
                                const char * actorRegistrationString);

void pony_root_destroy_actor_to_node(const char * actorUUID, int nodeSocketFD);
void pony_node_destroy_actor_to_root(int socketfd);

uint64_t pony_actor_new_then_id();

bool pony_startup(void);
void pony_shutdown(bool waitForRemotes);

int pony_core_count();
int pony_e_core_count();
int pony_p_core_count();
bool pony_core_affinity_enabled();

void * pony_actor_create();

void pony_actor_mark_then_id(const void *  file, uint64_t then_id);
uint64_t pony_actor_get_then_id(const void * file, uint64_t line);

void pony_actor_send_message(void * actor, void * argumentPtr, uint64_t then_id, void (*handleMessageFunc)(void * message));
void pony_actor_complete_then_message(void * actor, void * argumentPtr, void (*handleMessageFunc)(void * message));
void pony_actor_then_message(void * actor, uint64_t then_id);

void pony_actor_setpriority(void * actor, int priority);
int pony_actor_getpriority(void * actor);

void pony_actor_setbatchSize(void * actor, int batchSize);
int pony_actor_getbatchSize(void * actor);

void pony_actor_setcoreAffinity(void * actor, int coreAffinity);
int pony_actor_getcoreAffinity(void * actor);

void pony_actor_yield(void * actor);
void pony_actor_suspend(void * actor);
void pony_actor_resume(void * actor);
bool pony_actor_is_suspended(void * actor);

int pony_actor_num_messages(void * actor);
void pony_actor_destroy(void * actor);

int pony_actors_load_balance(void * actorArray, int num_actors);

bool pony_actors_should_wait(int min_msgs, void * actorArray, int num_actors);
void pony_actors_wait(int min_msgs, void * actor, int num_actors);
void pony_actor_wait(int min_msgs, void * actor);

unsigned long pony_max_memory();
unsigned long pony_current_memory();
unsigned long pony_mapped_memory();

void pony_syslog(const char * tag, const char * msg);

#endif
