
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

// MARK: - SLAVE

#define kMaxIPAddress 128

typedef struct master_t
{
    char address[kMaxIPAddress];
    int port;
    int socketfd;
    CreateActorFunc createActorFuncPtr;
    DestroyActorFunc destroyActorFuncPtr;
    MessageActorFunc messageActorFuncPtr;
    pony_thread_id_t thread_tid;
} master_t;

#define kMaxMasters 2048

static master_t masters[kMaxMasters+1] = {0};

static pthread_mutex_t masters_mutex;
static bool inited = false;

static DECLARE_THREAD_FN(slave_read_from_master_thread);

static master_t * find_master_by_socket(int socketfd) {
    master_t * ptr = masters;
    while (ptr < (masters + kMaxMasters) && ptr->socketfd > 0) {
        if (ptr->socketfd == socketfd) {
            return ptr;
        }
        ptr++;
    }
    return NULL;
}

static bool slave_add_master(const char * address,
                             int port,
                             CreateActorFunc createActorFuncPtr,
                             DestroyActorFunc destroyActorFuncPtr,
                             MessageActorFunc messageActorFuncPtr) {
    for (int i = 0; i < kMaxMasters; i++) {
        if (masters[i].socketfd == 0) {
            pthread_mutex_lock(&masters_mutex);
            masters[i].socketfd = -1;
            strncpy(masters[i].address, address, kMaxIPAddress);
            masters[i].port = port;
            masters[i].createActorFuncPtr = createActorFuncPtr;
            masters[i].destroyActorFuncPtr = destroyActorFuncPtr;
            masters[i].messageActorFuncPtr = messageActorFuncPtr;
            ponyint_thread_create(&masters[i].thread_tid, slave_read_from_master_thread, QOS_CLASS_BACKGROUND, masters + i);
            pthread_mutex_unlock(&masters_mutex);
            return true;
        }
    }
    return false;
}

static void slave_remove_master(master_t * masterPtr) {
    if (masterPtr->socketfd != 0) {
        close_socket(masterPtr->socketfd);
        masterPtr->thread_tid = 0;
        masterPtr->port = 0;
        masterPtr->createActorFuncPtr = NULL;
        masterPtr->destroyActorFuncPtr = NULL;
        masterPtr->messageActorFuncPtr = NULL;
        masterPtr->address[0] = 0;
        masterPtr->socketfd = 0;
    }
}

static void slave_remove_all_masters() {
    for (int i = 0; i < kMaxMasters; i++) {
        slave_remove_master(masters + i);
    }
}

static DECLARE_THREAD_FN(slave_read_from_master_thread)
{
    master_t * masterPtr = (master_t *) arg;
    
    char name[256] = {0};
    snprintf(name, sizeof(name), "Flynn Slave to %s:%d", masterPtr->address, masterPtr->port);
    ponyint_thead_setname_actual(name);
        
    socklen_t len;
    struct sockaddr_in servaddr = {0};
    struct sockaddr_in clientaddr = {0};
    
    servaddr.sin_family = AF_INET;
    inet_pton(AF_INET, masterPtr->address, &(servaddr.sin_addr));
    servaddr.sin_port = htons(masterPtr->port);
    
    while (masterPtr->thread_tid != 0) {
        
        // socket create and verification
        masterPtr->socketfd = socket(AF_INET, SOCK_STREAM, 0);
        if (masterPtr->socketfd == -1) {
            fprintf(stderr, "Flynn Slave socket creation failed, exiting...\n");
            exit(1);
        }
        
        if (connect(masterPtr->socketfd, (struct sockaddr*)&servaddr, sizeof(servaddr)) != 0) {
#if REMOTE_DEBUG
            fprintf(stderr, "[%d] attempting to reconnect to master\n", masterPtr->socketfd);
#endif
            close(masterPtr->socketfd);
            sleep(1);
            continue;
        }
        
        send_version_check(masterPtr->socketfd);
        send_core_count(masterPtr->socketfd);
        
        while(masterPtr->socketfd > 0) {
#if REMOTE_DEBUG
            fprintf(stderr, "[%d] slave reading socket\n", masterPtr->socketfd);
#endif
            
            // read the command byte
            uint8_t command = read_command(masterPtr->socketfd);
            
            if (command != COMMAND_VERSION_CHECK &&
                command != COMMAND_CREATE_ACTOR &&
                command != COMMAND_DESTROY_ACTOR &&
                command != COMMAND_SEND_MESSAGE) {
                slave_remove_master(masterPtr);
                ponyint_pool_thread_cleanup();
                return 0;
            }
            
            // read the size of the uuid
            char uuid[128] = {0};
            if (!read_bytecount_buffer(masterPtr->socketfd, uuid, sizeof(uuid)-1)) {
                slave_remove_master(masterPtr);
                ponyint_pool_thread_cleanup();
                return 0;
            }

            
            switch (command) {
                case COMMAND_VERSION_CHECK: {
                    if (strncmp(BUILD_VERSION_UUID, uuid, strlen(BUILD_VERSION_UUID)) != 0) {
#if REMOTE_DEBUG
                        fprintf(stdout, "[%d] master/slave version mismatch ( %s != %s )\n", masterPtr->socketfd, uuid, BUILD_VERSION_UUID);
#endif
                        continue;
                    }
                } break;
                case COMMAND_CREATE_ACTOR: {
                    char type[128] = {0};
                    if (!read_bytecount_buffer(masterPtr->socketfd, type, sizeof(type)-1)) {
                        slave_remove_master(masterPtr);
                        ponyint_pool_thread_cleanup();
                        return 0;
                    }
                    
                    masterPtr->createActorFuncPtr(uuid, type);
                    
#if REMOTE_DEBUG
                    fprintf(stdout, "[%d] COMMAND_CREATE_ACTOR[%s, %s]\n", masterPtr->socketfd, uuid, type);
#endif
                } break;
                case COMMAND_DESTROY_ACTOR:
                    
                    masterPtr->destroyActorFuncPtr(uuid);
                    
#if REMOTE_DEBUG
                    fprintf(stdout, "[%d] COMMAND_DESTROY_ACTOR[%s]\n", masterPtr->socketfd, uuid);
#endif
                    break;
                case COMMAND_SEND_MESSAGE: {
                    char behavior[128] = {0};
                    if (!read_bytecount_buffer(masterPtr->socketfd, behavior, sizeof(behavior)-1)) {
                        slave_remove_master(masterPtr);
                        ponyint_pool_thread_cleanup();
                        return 0;
                    }
                    
                    uint32_t payload_count = 0;
                    recvall(masterPtr->socketfd, &payload_count, sizeof(uint32_t));
                    payload_count = ntohl(payload_count);
                    
                    uint8_t * bytes = malloc(payload_count);
                    recvall(masterPtr->socketfd, bytes, payload_count);
                    
                    masterPtr->messageActorFuncPtr(uuid, behavior, bytes, payload_count, masterPtr->socketfd);
                    
    #if REMOTE_DEBUG
                    fprintf(stdout, "[%d] COMMAND_SEND_MESSAGE[%s, %s] %d bytes\n", masterPtr->socketfd, uuid, behavior, payload_count);
    #endif
                } break;
            }
        }
        slave_remove_master(masterPtr);
    }
    
    ponyint_pool_thread_cleanup();
    
    return 0;
}

void pony_slave(const char * address,
                int port,
                CreateActorFunc createActorFuncPtr,
                DestroyActorFunc destroyActorFuncPtr,
                MessageActorFunc messageActorFuncPtr) {
    if (inited == false) {
        inited = true;
        pthread_mutex_init(&masters_mutex, NULL);
    }
    
    if(!slave_add_master(address,
                         port,
                         createActorFuncPtr,
                         destroyActorFuncPtr,
                         messageActorFuncPtr)) {
        fprintf(stderr, "Flynn Slave failed to add master, maximum number of masters exceeded\n");
        return;
    }
}

void slave_shutdown() {
    slave_remove_all_masters();
}

// MARK: - MESSAGES

void pony_remote_actor_send_message_to_master(int socketfd, const char * actorUUID, const void * bytes, int count) {
    // When a slave is sending back to a master, they send a message by knowing the recipients actor uuid
    // The master knows which messages it sent which are expecting a reply, so it is garaunteed they
    // will be delivered back in order
    
    pthread_mutex_lock(&masters_mutex);
    send_reply(socketfd, actorUUID, bytes, count);
    pthread_mutex_unlock(&masters_mutex);
}
