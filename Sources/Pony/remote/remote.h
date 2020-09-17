
#include "platform.h"


extern char * BUILD_VERSION_UUID;

#define REMOTE_DEBUG 0

#define COMMAND_NULL 0
#define COMMAND_VERSION_CHECK 1
#define COMMAND_CREATE_ACTOR 2
#define COMMAND_DESTROY_ACTOR 3
#define COMMAND_SEND_MESSAGE 4
#define COMMAND_SEND_REPLY 5
#define COMMAND_CORE_COUNT 6

typedef void (*CreateActorFunc)(const char * actorUUID, const char * actorType);
typedef void (*DestroyActorFunc)(const char * actorUUID);
typedef void (*MessageActorFunc)(const char * actorUUID, const char * behavior, void * payload, int payloadSize, int replySocketFD);
typedef void (*ReplyMessageFunc)(const char * actorUUID, void * payload, int payloadSize);

extern int recvall(int fd, void * ptr, int size);
extern int sendall(int fd, void * ptr, int size);

extern uint8_t read_command(int socketfd);
extern char * read_intcount_buffer(int socketfd, uint32_t * count);
extern bool read_bytecount_buffer(int socketfd, char * dst, size_t max_length);

extern void send_buffer(int socketfd, char * bytes, size_t length);
extern void send_version_check(int socketfd);
extern void send_core_count(int socketfd);
extern void send_create_actor(int socketfd, const char * actorUUID, const char * actorType);
extern void send_destroy_actor(int socketfd, const char * actorUUID);

extern void send_message(int socketfd, const char * actorUUID, const char * behaviorType, const void * bytes, uint32_t count);
extern void send_reply(int socketfd, const char * actorUUID, const void * bytes, uint32_t count);

extern void close_socket(int fd);
