
#include "platform.h"

#ifdef PLATFORM_SUPPORTS_REMOTES

#ifndef PLATFORM_IS_APPLE
#define QOS_CLASS_USER_INTERACTIVE 0
#define QOS_CLASS_USER_INITIATED 0
#define QOS_CLASS_DEFAULT 0
#define QOS_CLASS_UTILITY 1
#define QOS_CLASS_BACKGROUND 1
#define QOS_CLASS_UNSPECIFIED 1
#endif


extern char * BUILD_VERSION_UUID;

#define REMOTE_DEBUG 0

#define COMMAND_NULL 0
#define COMMAND_VERSION_CHECK 1
#define COMMAND_REGISTER_WITH_ROOT 2
#define COMMAND_CREATE_ACTOR 3
#define COMMAND_DESTROY_ACTOR 4
#define COMMAND_SEND_MESSAGE 5
#define COMMAND_SEND_REPLY 6
#define COMMAND_CORE_COUNT 7
#define COMMAND_HEARTBEAT 8
#define COMMAND_DESTROY_ACTOR_ACK 9

typedef void (*NodeDisconnectedFunc)(int socketFD);
typedef void (*RegisterWithRootFunc)(const char * registrationString, int socketFD);
typedef void (*CreateActorFunc)(const char * actorUUID, const char * actorType, bool, int socketFD);
typedef void (*DestroyActorFunc)(const char * actorUUID);
typedef void (*MessageActorFunc)(const char * actorUUID, const char * behavior, void * payload, int payloadSize, int messageID, int replySocketFD);
typedef void (*RegisterActorsOnRootFunc)(int replySocketFD);

typedef void (*ReplyMessageFunc)(uint32_t messageID, void * payload, int payloadSize);

extern void cork(int fd);
extern void uncork(int fd);

extern int recvall(int fd, void * ptr, int size);
extern int sendall(int fd, void * ptr, int size);

extern uint8_t read_command(int socketfd);
extern bool read_int(int socketfd, uint32_t * count);
extern char * read_intcount_buffer(int socketfd, uint32_t * count);
extern bool read_bytecount_buffer(int socketfd, char * dst, size_t max_length);

extern void send_buffer(int socketfd, char * bytes, size_t length);

extern void close_socket(int fd);

extern void disableSIGPIPE(int fd);

#endif