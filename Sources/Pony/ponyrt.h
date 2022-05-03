
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#ifndef ponyrt_h
#define ponyrt_h

#include <stdio.h>
#include <assert.h>
#include <sys/types.h>
#include <stdbool.h>
#include "atomics.h"

void pony_remote_shutdown();

#define kDestroyMessage 0
#define kMessagePointer 1
#define kRemote_Version 2
#define kRemote_RegisterWithRoot 3
#define kRemote_CreateActor 4
#define kRemote_DestroyActor 5
#define kRemote_SendMessage 6
#define kRemote_SendReply 7
#define kRemote_SendCoreCount 8
#define kRemote_SendHeartbeat 9
#define kRemote_DestroyActorAck 10

typedef struct pony_actor_t pony_actor_t;

typedef struct pony_ctx_t pony_ctx_t;

/** Message header.
 *
 * This must be the first field in any message structure. The ID is used for
 * dispatch. The index is a pool allocator index and is used for freeing the
 * message. The next pointer should not be read or set.
 */
typedef struct pony_msg_t pony_msg_t;

struct pony_msg_t
{
    uint32_t alloc_size;
    uint32_t msgId;
    PONY_ATOMIC(pony_msg_t*) next;
};

/// Convenience message for sending an integer.
typedef struct pony_msgi_t
{
    pony_msg_t msg;
    intptr_t i;
} pony_msgi_t;

/// Convenience message for sending a pointer.
typedef struct pony_msgp_t
{
    pony_msg_t msg;
    void* p;
} pony_msgp_t;

/// Convenience message for sending two pointers.
typedef struct pony_msgpp_t
{
    pony_msg_t msg;
    void* p1;
    void* p2;
} pony_msgpp_t;

/// Convenience message for sending two pointers.
typedef struct pony_msgfunc_t
{
    pony_msg_t msg;
    void* arg;
    void (*func)(void * message);
} pony_msgfunc_t;

/// Convenience message for sending remote message.
typedef struct pony_msg_remote_version_t
{
    pony_msg_t msg;
} pony_msg_remote_version_t;

typedef struct pony_msg_remote_createactor_t
{
    pony_msg_t msg;
    char actorUUID[128];
    char actorType[128];
} pony_msg_remote_createactor_t;

typedef struct pony_msg_remote_destroyactor_t
{
    pony_msg_t msg;
    char actorUUID[128];
} pony_msg_remote_destroyactor_t;

typedef struct pony_msg_remote_sendmessage_t
{
    pony_msg_t msg;
    uint32_t messageId;
    char actorUUID[128];
    char behaviorType[128];
    void * payload;
    uint32_t length;
} pony_msg_remote_sendmessage_t;


typedef struct pony_msg_remote_register_t
{
    pony_msg_t msg;
    char * registration;
    uint32_t length;
} pony_msg_remote_register_t;

typedef struct pony_msg_remote_core_count_t
{
    pony_msg_t msg;
} pony_msg_remote_core_count_t;

typedef struct pony_msg_remote_heartbeat_t
{
    pony_msg_t msg;
} pony_msg_remote_heartbeat_t;

typedef struct pony_msg_remote_destroy_actor_ack_t
{
    pony_msg_t msg;
} pony_msg_remote_destroy_actor_ack_t;

typedef struct pony_msg_remote_sendreply_t
{
    pony_msg_t msg;
    uint32_t messageId;
    void * payload;
    uint32_t length;
} pony_msg_remote_sendreply_t;

#endif /* ponyrt_h */
