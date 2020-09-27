
#include "platform.h"

#include <stdlib.h>
#include <netdb.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <arpa/inet.h>
#include <string.h>
#include <unistd.h>

#include "../ponyrt.h"

#include "../messageq.h"
#include "../scheduler.h"
#include "../actor.h"
#include "../cpu.h"
#include "../alloc.h"
#include "../pool.h"

#include "remote.h"

// MARK: - NODE

#define kMaxIPAddress 128

typedef struct root_t
{
    char address[kMaxIPAddress];
    int port;
    int socketfd;
    CreateActorFunc createActorFuncPtr;
    DestroyActorFunc destroyActorFuncPtr;
    MessageActorFunc messageActorFuncPtr;
    RegisterActorsOnRootFunc registerActorsOnRootFuncPtr;
    pony_thread_id_t thread_tid;
} root_t;

#define kMaxRoots 2048

static root_t roots[kMaxRoots+1] = {0};

static pthread_mutex_t roots_mutex;
static bool inited = false;

static DECLARE_THREAD_FN(node_read_from_root_thread);

static void init_all_roots() {
    root_t * ptr = roots;
    while (ptr < (roots + kMaxRoots)) {
        ptr->socketfd = -1;
        ptr++;
    }
}

static root_t * find_root_by_socket(int socketfd) {
    root_t * ptr = roots;
    while (ptr < (roots + kMaxRoots) && ptr->socketfd >= 0) {
        if (ptr->socketfd == socketfd) {
            return ptr;
        }
        ptr++;
    }
    return NULL;
}

static bool node_add_root(const char * address,
                          int port,
                          CreateActorFunc createActorFuncPtr,
                          DestroyActorFunc destroyActorFuncPtr,
                          MessageActorFunc messageActorFuncPtr,
                          RegisterActorsOnRootFunc registerActorsOnRootFuncPtr) {
    for (int i = 0; i < kMaxRoots; i++) {
        if (roots[i].thread_tid == 0) {
            pthread_mutex_lock(&roots_mutex);
            strncpy(roots[i].address, address, kMaxIPAddress);
            roots[i].port = port;
            roots[i].createActorFuncPtr = createActorFuncPtr;
            roots[i].destroyActorFuncPtr = destroyActorFuncPtr;
            roots[i].messageActorFuncPtr = messageActorFuncPtr;
            roots[i].registerActorsOnRootFuncPtr = registerActorsOnRootFuncPtr;
            ponyint_thread_create(&roots[i].thread_tid, node_read_from_root_thread, QOS_CLASS_BACKGROUND, roots + i);
            pthread_mutex_unlock(&roots_mutex);
            return true;
        }
    }
    return false;
}

static void node_remove_root(root_t * rootPtr) {
    if (rootPtr->thread_tid != 0) {
        close_socket(rootPtr->socketfd);
        ponyint_thread_join(rootPtr->thread_tid);
        rootPtr->thread_tid = 0;
        rootPtr->port = 0;
        rootPtr->createActorFuncPtr = NULL;
        rootPtr->destroyActorFuncPtr = NULL;
        rootPtr->messageActorFuncPtr = NULL;
        rootPtr->registerActorsOnRootFuncPtr = NULL;
        rootPtr->address[0] = 0;
        rootPtr->socketfd = -1;
    }
}

static void node_remove_all_roots() {
    for (int i = 0; i < kMaxRoots; i++) {
        node_remove_root(roots + i);
    }
}

static DECLARE_THREAD_FN(node_read_from_root_thread)
{
    root_t * rootPtr = (root_t *) arg;
    
    char name[256] = {0};
    snprintf(name, sizeof(name), "Flynn Node to %s:%d", rootPtr->address, rootPtr->port);
    ponyint_thead_setname_actual(name);
        
    socklen_t len;
    struct sockaddr_in servaddr = {0};
    struct sockaddr_in clientaddr = {0};
    
    servaddr.sin_family = AF_INET;
    inet_pton(AF_INET, rootPtr->address, &(servaddr.sin_addr));
    servaddr.sin_port = htons(rootPtr->port);
    
    while (rootPtr->thread_tid != 0) {
        
        // socket create and verification
        rootPtr->socketfd = socket(AF_INET, SOCK_STREAM, 0);
        if (rootPtr->socketfd < 0) {
            fprintf(stderr, "Flynn Node socket creation failed, exiting...\n");
            exit(1);
        }
        
        fprintf(stdout, "attempting to connect to root %s:%d\n", rootPtr->address, rootPtr->port);
        if (connect(rootPtr->socketfd, (struct sockaddr*)&servaddr, sizeof(servaddr)) != 0) {
#if REMOTE_DEBUG
            fprintf(stderr, "[%d] attempting to reconnect to root\n", rootPtr->socketfd);
#endif
            close_socket(rootPtr->socketfd);
            sleep(1);
            continue;
        }
        
        send_version_check(rootPtr->socketfd);
        
        rootPtr->registerActorsOnRootFuncPtr(rootPtr->socketfd);
        
        send_core_count(rootPtr->socketfd);
        
        fprintf(stdout, "connected to root %s:%d\n", rootPtr->address, rootPtr->port);
        while(rootPtr->socketfd >= 0) {
#if REMOTE_DEBUG
            fprintf(stderr, "[%d] node reading socket\n", rootPtr->socketfd);
#endif
            
            // read the command byte
            uint8_t command = read_command(rootPtr->socketfd);
            
            if (command != COMMAND_VERSION_CHECK &&
                command != COMMAND_CREATE_ACTOR &&
                command != COMMAND_DESTROY_ACTOR &&
                command != COMMAND_SEND_MESSAGE) {
                node_remove_root(rootPtr);
                ponyint_pool_thread_cleanup();
                return 0;
            }
                        
            // read the size of the uuid
            char uuid[128] = {0};
            if (!read_bytecount_buffer(rootPtr->socketfd, uuid, sizeof(uuid)-1)) {
                node_remove_root(rootPtr);
                ponyint_pool_thread_cleanup();
                return 0;
            }

            
            switch (command) {
                case COMMAND_VERSION_CHECK: {
                    if (strncmp(BUILD_VERSION_UUID, uuid, strlen(BUILD_VERSION_UUID)) != 0) {
#if REMOTE_DEBUG
                        fprintf(stdout, "[%d] node -> root version mismatch ( [%s] != [%s] )\n", rootPtr->socketfd, uuid, BUILD_VERSION_UUID);
#endif
                    }
                } break;
                case COMMAND_CREATE_ACTOR: {
                    char type[128] = {0};
                    if (!read_bytecount_buffer(rootPtr->socketfd, type, sizeof(type)-1)) {
                        node_remove_root(rootPtr);
                        ponyint_pool_thread_cleanup();
                        return 0;
                    }
                    
                    rootPtr->createActorFuncPtr(uuid, type, rootPtr->socketfd);
                    
#if REMOTE_DEBUG
                    fprintf(stdout, "[%d] COMMAND_CREATE_ACTOR(node)[%s, %s]\n", rootPtr->socketfd, uuid, type);
#endif
                } break;
                case COMMAND_DESTROY_ACTOR:
                    
                    rootPtr->destroyActorFuncPtr(uuid);
                    
#if REMOTE_DEBUG
                    fprintf(stdout, "[%d] COMMAND_DESTROY_ACTOR[%s]\n", rootPtr->socketfd, uuid);
#endif
                    break;
                case COMMAND_SEND_MESSAGE: {
                    
                    char behavior[128] = {0};
                    if (!read_bytecount_buffer(rootPtr->socketfd, behavior, sizeof(behavior)-1)) {
                        node_remove_root(rootPtr);
                        ponyint_pool_thread_cleanup();
                        return 0;
                    }
                    
                    uint32_t messageID = 0;
                    if (!read_int(rootPtr->socketfd, &messageID)) {
                        node_remove_root(rootPtr);
                        ponyint_pool_thread_cleanup();
                        return 0;
                    }
                    
                    uint32_t payload_count = 0;
                    recvall(rootPtr->socketfd, &payload_count, sizeof(uint32_t));
                    payload_count = ntohl(payload_count);
                    
                    uint8_t * bytes = malloc(payload_count);
                    recvall(rootPtr->socketfd, bytes, payload_count);
                    
                    rootPtr->messageActorFuncPtr(uuid, behavior, bytes, payload_count, messageID, rootPtr->socketfd);
                    
    #if REMOTE_DEBUG
                    fprintf(stdout, "[%d] COMMAND_SEND_MESSAGE[%s, %s] %d bytes\n", rootPtr->socketfd, uuid, behavior, payload_count);
    #endif
                } break;
            }
        }
        node_remove_root(rootPtr);
    }
    
    ponyint_pool_thread_cleanup();
    
    return 0;
}

void pony_node(const char * address,
               int port,
               CreateActorFunc createActorFuncPtr,
               DestroyActorFunc destroyActorFuncPtr,
               MessageActorFunc messageActorFuncPtr,
               RegisterActorsOnRootFunc registerActorsOnRootFuncPtr) {
    if (inited == false) {
        inited = true;
        init_all_roots();
        pthread_mutex_init(&roots_mutex, NULL);
    }
    
    if(!node_add_root(address,
                      port,
                      createActorFuncPtr,
                      destroyActorFuncPtr,
                      messageActorFuncPtr,
                      registerActorsOnRootFuncPtr)) {
        fprintf(stderr, "Flynn node failed to add root, maximum number of roots exceeded\n");
        return;
    }
}

void node_shutdown() {
    node_remove_all_roots();
}

// MARK: - MESSAGES

void pony_remote_actor_send_message_to_root(int socketfd, int messageID, const void * bytes, int count) {
    // When a node is sending back to a root, they send a message by knowing the recipients actor uuid
    // The root knows which messages it sent which are expecting a reply, so it is garaunteed they
    // will be delivered back in order
    
    pthread_mutex_lock(&roots_mutex);
    send_reply(socketfd, messageID, bytes, count);
    pthread_mutex_unlock(&roots_mutex);
}

void pony_send_remote_actor_to_root(int socketfd, const char * actorUUID, const char * actorType) {
    pthread_mutex_lock(&roots_mutex);
    send_create_actor(socketfd, actorUUID, actorType);
    pthread_mutex_unlock(&roots_mutex);
}
