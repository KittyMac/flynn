
#include "platform.h"

#include <signal.h>
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

// MARK: - MASTER

static int number_of_slaves = 0;
static int number_of_cores = 0;

int ponyint_remote_slaves_count() {
    return number_of_slaves;
}

int ponyint_remote_core_count()
{
    return number_of_cores;
}

// Kept by the master to know which slaves are actively connected
typedef struct slave_t
{
    int socketfd;
    pony_thread_id_t thread_tid;
    uint32_t core_count;
} slave_t;

#define kMaxSlaves 2048

static slave_t slaves[kMaxSlaves+1] = {0};

static pthread_mutex_t slaves_mutex;

static pony_thread_id_t master_tid;
static char master_ip_address[128] = {0};
static int master_tcp_port = 9999;
static ReplyMessageFunc replyMessageFuncPtr = NULL;
static int master_listen_socket = 0;

static DECLARE_THREAD_FN(master_read_from_slave_thread);

static slave_t * find_slave_by_socket(int socketfd) {
    slave_t * ptr = slaves;
    while (ptr < (slaves + kMaxSlaves) && ptr->socketfd > 0) {
        if (ptr->socketfd == socketfd) {
            return ptr;
        }
        ptr++;
    }
    return NULL;
}

static slave_t * master_get_next_slave() {
    static int next_slave_index = 0;
    
    slave_t * slavePtr = slaves + next_slave_index;
    for (int i = 0; i < kMaxSlaves; i++) {
        slavePtr++;
        if (slavePtr >= slaves + kMaxSlaves) {
            slavePtr = slaves;
        }
        if (slavePtr->socketfd > 0) {
            next_slave_index = slavePtr - slaves;
            return slavePtr;
        }
    }
    
    return NULL;
}

static bool master_add_slave(int socketfd) {
    pthread_mutex_lock(&slaves_mutex);
    for (int i = 0; i < kMaxSlaves; i++) {
        if (slaves[i].socketfd == 0) {
            slaves[i].socketfd = socketfd;
            ponyint_thread_create(&slaves[i].thread_tid, master_read_from_slave_thread, QOS_CLASS_BACKGROUND, slaves + i);
            number_of_slaves++;
            pthread_mutex_unlock(&slaves_mutex);
            return true;
        }
    }
    pthread_mutex_unlock(&slaves_mutex);
    return false;
}

static void master_remove_slave(slave_t * slavePtr) {
    if (slavePtr->socketfd > 0) {
        pthread_mutex_lock(&slaves_mutex);
        number_of_cores -= slavePtr->core_count;
        number_of_slaves--;
        
        close_socket(slavePtr->socketfd);
        slavePtr->thread_tid = 0;
        slavePtr->socketfd = 0;
        slavePtr->core_count = 0;
        pthread_mutex_unlock(&slaves_mutex);
    }
}

static void master_remove_all_slaves() {
    for (int i = 0; i < kMaxSlaves; i++) {
        master_remove_slave(slaves+i);
    }
}

static DECLARE_THREAD_FN(master_read_from_slave_thread)
{
    // master reading information sent from slave. The only valid command
    // slave -> master is COMMAND_SEND_REPLY.  Any miscommunication from
    // the slave results in the immediate termination of the connection
    slave_t * slavePtr = (slave_t *) arg;
    
    send_version_check(slavePtr->socketfd);
    
    while(slavePtr->socketfd > 0) {
        
#if REMOTE_DEBUG
        fprintf(stderr, "[%d] master reading socket\n", slavePtr->socketfd);
#endif
        
        // read the command byte
        uint8_t command = read_command(slavePtr->socketfd);
        if (command != COMMAND_VERSION_CHECK &&
            command != COMMAND_CORE_COUNT &&
            command != COMMAND_SEND_REPLY) {
            master_remove_slave(slavePtr);
            return 0;
        }
        
        // read the size of the uuid
        char uuid[128] = {0};
        if (command == COMMAND_VERSION_CHECK ||
            command == COMMAND_SEND_REPLY) {
            if (!read_bytecount_buffer(slavePtr->socketfd, uuid, sizeof(uuid)-1)) {
                master_remove_slave(slavePtr);
                return 0;
            }
        }
        
        switch(command) {
            case COMMAND_VERSION_CHECK: {
                if (strncmp(BUILD_VERSION_UUID, uuid, strlen(BUILD_VERSION_UUID)) != 0) {
                    fprintf(stdout, "warning: master/slave version mismatch ( %s != %s )\n", uuid, BUILD_VERSION_UUID);
                    //master_remove_slave(slavePtr);
                    //return 0;
                }
            } break;
            case COMMAND_CORE_COUNT: {
                uint32_t core_count = 0;
                recvall(slavePtr->socketfd, &core_count, sizeof(core_count));
                core_count = ntohl(core_count);
                
                pthread_mutex_lock(&slaves_mutex);
                number_of_cores = number_of_cores - slavePtr->core_count + core_count;
                pthread_mutex_unlock(&slaves_mutex);

                slavePtr->core_count = core_count;
                
            } break;
            case COMMAND_SEND_REPLY: {
                uint32_t payload_count = 0;
                char * payload = read_intcount_buffer(slavePtr->socketfd, &payload_count);                
                replyMessageFuncPtr(uuid, payload, payload_count);
                
#if REMOTE_DEBUG
                fprintf(stdout, "[%d] COMMAND_SEND_REPLY[%s] %d bytes\n", slavePtr->socketfd, uuid, payload_count);
#endif
            } break;
        }
    }
    
    master_remove_slave(slavePtr);
    
    return 0;
}

static DECLARE_THREAD_FN(master_thread)
{
    ponyint_thead_setname_actual("Flynn Master #0");
        
    socklen_t len;
    int socketfd, connectionfd;
    struct sockaddr_in servaddr = {0};
    struct sockaddr_in clientaddr = {0};

    // socket create and verification
    socketfd = socket(AF_INET, SOCK_STREAM, 0);
    if (socketfd == -1) {
        fprintf(stderr, "Flynn Master socket creation failed, exiting...\n");
        exit(1);
    }
    
    master_listen_socket = socketfd;

    servaddr.sin_family = AF_INET;
    inet_pton(AF_INET, master_ip_address, &(servaddr.sin_addr));
    servaddr.sin_port = htons(master_tcp_port);
    
    if ((bind(socketfd, (struct sockaddr *)&servaddr, sizeof(servaddr))) != 0) {
        close_socket(socketfd);
        perror("Flynn Master socket bind failed, exiting. Error");
        exit(1);
    }
    
#if REMOTE_DEBUG
    fprintf(stderr, "[%d] master listen socket\n", master_listen_socket);
#endif
    while(master_listen_socket > 0) {
        if ((listen(socketfd, 32)) != 0) {
            fprintf(stderr, "Flynn Master socket listen failed, ending master listen thread\n");
            close_socket(socketfd);
            ponyint_pool_thread_cleanup();
            return 0;
        }
        
        connectionfd = accept(socketfd, (struct sockaddr*)&clientaddr, &len);
        if (connectionfd < 0) {
            fprintf(stderr, "Flynn Master failed to accept incoming connection, skipping...\n");
            continue;
        }
        
        if(!master_add_slave(connectionfd)) {
            fprintf(stderr, "Flynn Master failed to add slave, maximum number of slaves exceeded\n");
            close_socket(socketfd);
            ponyint_pool_thread_cleanup();
            return 0;
        }
    }
    
    close_socket(socketfd);
    ponyint_pool_thread_cleanup();
    return 0;
}

void pony_master(const char * address,
                 int port,
                 ReplyMessageFunc replyFunc) {
    if (master_listen_socket > 0) { return; }
    
    sigaction(SIGPIPE, &(struct sigaction){SIG_IGN}, NULL);
    
    pthread_mutex_init(&slaves_mutex, NULL);
    
    replyMessageFuncPtr = replyFunc;
    
    strncpy(master_ip_address, address, sizeof(master_ip_address)-1);
    master_tcp_port = port;
    
    ponyint_thread_create(&master_tid, master_thread, QOS_CLASS_BACKGROUND, NULL);
}

void master_shutdown() {
    close_socket(master_listen_socket);
    master_listen_socket = 0;
    ponyint_thread_join(master_tid);
    
    master_remove_all_slaves();
}


// MARK: - MESSAGES

void pony_remote_actor_send_message_to_slave(const char * actorUUID, const char * actorType, const char * behaviorType, int * slaveSocketFD, const void * bytes, int count) {
    if (*slaveSocketFD < 0) {
        slave_t * slavePtr = master_get_next_slave();
        if (slavePtr == NULL) {
            fprintf(stderr, "error: RemoteActor behavior called but no slaves are connected to master\n");
            return;
        }
        *slaveSocketFD = slavePtr->socketfd;
        send_create_actor(*slaveSocketFD, actorUUID, actorType);
    }
    
    if (send_message(*slaveSocketFD, actorUUID, behaviorType, bytes, count) < 0) {
        // we lost connection with this remote actor
        *slaveSocketFD = -1;
    }
}

void pony_remote_destroy_actor(const char * actorUUID, int * slaveSocketFD) {
    if (*slaveSocketFD >= 0) {
        slave_t * ptr = find_slave_by_socket(*slaveSocketFD);
        if (ptr != NULL) {
            send_destroy_actor(ptr->socketfd, actorUUID);
        }
    }
}
