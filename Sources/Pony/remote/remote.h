
#include "platform.h"
/*
#include <stdlib.h>
#include <netdb.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <arpa/inet.h>
#include <string.h>
#include <unistd.h>

#include "ponyrt.h"

#include "messageq.h"
#include "scheduler.h"
#include "actor.h"
#include "cpu.h"
#include "alloc.h"
#include "pool.h"

*/

extern char * BUILD_VERSION_UUID;

#define COMMAND_NULL 0
#define COMMAND_VERSION_CHECK 1
#define COMMAND_CREATE_ACTOR 2
#define COMMAND_DESTROY_ACTOR 3
#define COMMAND_SEND_MESSAGE 4
#define COMMAND_SEND_REPLY 5

extern uint8_t read_command(int socketfd);
extern char * read_intcount_buffer(int socketfd, uint32_t * count);
extern bool read_bytecount_buffer(int socketfd, char * dst, size_t max_length);

extern void send_buffer(int socketfd, char * bytes, size_t length);
extern void send_version_check(int socketfd);
extern void send_create_actor(int socketfd, const char * actorUUID, const char * actorType);
extern void send_destroy_actor(int socketfd, const char * actorUUID);

extern void send_message(int socketfd, const char * actorUUID, const char * behaviorType, const void * bytes, uint32_t count);

extern void close_socket(int fd);
