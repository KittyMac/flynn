
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

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

#define COMMAND_NULL 0
#define COMMAND_CREATE_ACTOR 1
#define COMMAND_DESTROY_ACTOR 2
#define COMMAND_SEND_MESSAGE 3
#define COMMAND_SEND_REPLY 4

// Communication between master and slave uses the following format:
//  bytes      meaning
//   [0] U8     type of command this is
//
//  COMMAND_CREATE_ACTOR (master -> slave)
//   [1] U8     number of bytes for actor uuid
//   [?]        actor uuid as string
//
//  COMMAND_DESTROY_ACTOR (master -> slave)
//   [1] U8     number of bytes for actor uuid
//   [?]        actor uuid as string
//
//  COMMAND_SEND_MESSAGE (master -> slave)
//   [1] U8     number of bytes for actor uuid
//   [?]        actor uuid as string
//   [0-4]      number of bytes for message data
//   [?]        message data
//
//  COMMAND_SEND_REPLY (master <- slave)
//
//
//
//

// MARK: - MASTER

static bool pony_master_is_listening = false;
static pony_thread_id_t master_tid;
static char master_ip_address[128] = {0};
static int master_tcp_port = 9999;

static int master_listen_socket = 0;
static int temp_master_to_slave_socketfd = 0;

static DECLARE_THREAD_FN(master_read_from_slave_thread)
{
    // master reading information sent from slave. The only valid command
    // slave -> master is COMMAND_SEND_REPLY.  Any miscommunication from
    // the slave results in the immediate termination of the connection
    int socketfd = (int) arg;
    
    temp_master_to_slave_socketfd = socketfd;
    
    while(pony_master_is_listening) {
        fprintf(stderr, "[%d] master reading socket\n", socketfd);
        
        // read the command byte
        uint8_t command = COMMAND_NULL;
        recv(socketfd, &command, 1, 0);
        
        if (command != COMMAND_SEND_REPLY) {
            close(socketfd);
            return;
        }
        
        // read the size of the uuid
        uint8_t uuid_count = 0;
        recv(socketfd, &uuid_count, 1, 0);
        
        // read the whole uuid
        if (uuid_count >= 127) {
            close(socketfd);
            return;
        }
        uint8_t uuid[128] = {0};
        recv(socketfd, uuid, uuid_count, 0);
        
        if (command == COMMAND_SEND_REPLY) {
            uint32_t payload_count = 0;
            recv(socketfd, &payload_count, sizeof(uint32_t), 0);
            payload_count = ntohl(payload_count);
            
            uint8_t * bytes = malloc(payload_count);
            recv(socketfd, bytes, payload_count, 0);
            
            fprintf(stdout, "[m] COMMAND_SEND_REPLY[%s] %d bytes\n", uuid, payload_count);
        }
    }
    
    close(socketfd);
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

    servaddr.sin_family = AF_INET;
    inet_pton(AF_INET, master_ip_address, &(servaddr.sin_addr));
    servaddr.sin_port = htons(master_tcp_port);
    
    if ((bind(socketfd, (struct sockaddr *)&servaddr, sizeof(servaddr))) != 0) {
        fprintf(stderr, "Flynn Master socket bind failed, exiting...\n");
        exit(1);
    }
    
    master_listen_socket = socketfd;
    
    fprintf(stderr, "[%d] master listen socket\n", master_listen_socket);
    while(pony_master_is_listening) {
        if ((listen(socketfd, 32)) != 0) {
            fprintf(stderr, "Flynn Master socket listen failed, ending master listen thread\n");
            ponyint_pool_thread_cleanup();
            return 0;
        }
        
        connectionfd = accept(socketfd, (struct sockaddr*)&clientaddr, &len);
        if (connectionfd < 0) {
            fprintf(stderr, "Flynn Master failed to accept incoming connection, skipping...\n");
            continue;
        }
        
        pony_thread_id_t master_to_slave_tid;
        ponyint_thread_create(&master_to_slave_tid, master_read_from_slave_thread, QOS_CLASS_BACKGROUND, connectionfd);
    }
    
    close(socketfd);
    
    ponyint_pool_thread_cleanup();
    return 0;
}

void pony_master(const char * address, int port) {
    if (pony_master_is_listening) { return; }
    
    pony_master_is_listening = true;
    
    strncpy(master_ip_address, address, sizeof(master_ip_address)-1);
    master_tcp_port = port;
    
    ponyint_thread_create(&master_tid, master_thread, QOS_CLASS_BACKGROUND, NULL);
    
    fprintf(stderr, "pony_master listen on %s:%d\n", address, port);
}

// MARK: - SLAVE

static bool pony_slave_is_connecting = false;
static pony_thread_id_t slave_tid;
static char slave_ip_address[128] = {0};
static int slave_tcp_port = 9999;

static int slave_to_master_socketfd = 0;

void slave_read_from_master_thread(int socketfd)
{
    while(pony_slave_is_connecting) {
        fprintf(stderr, "[%d] slave reading socket\n", socketfd);
        
        // read the command byte
        uint8_t command = COMMAND_NULL;
        read(socketfd, &command, 1);
        
        if (command != COMMAND_CREATE_ACTOR &&
            command != COMMAND_DESTROY_ACTOR &&
            command != COMMAND_SEND_MESSAGE) {
            close(socketfd);
            return;
        }
        
        // read the size of the uuid
        uint8_t uuid_count = 0;
        read(socketfd, &uuid_count, 1);
        
        // read the whole uuid
        if (uuid_count >= 126) {
            close(socketfd);
            return;
        }
        uint8_t uuid[128] = {0};
        read(socketfd, uuid, uuid_count);
        
        switch (command) {
            case COMMAND_CREATE_ACTOR:
                fprintf(stdout, "[s] COMMAND_CREATE_ACTOR[%s]\n", uuid);
                break;
            case COMMAND_DESTROY_ACTOR:
                fprintf(stdout, "[s] COMMAND_DESTROY_ACTOR[%s]\n", uuid);
                break;
            case COMMAND_SEND_MESSAGE: {
                uint32_t payload_count = 0;
                read(socketfd, &payload_count, sizeof(uint32_t));
                payload_count = ntohl(payload_count);
                
                uint8_t * bytes = malloc(payload_count);
                read(socketfd, bytes, payload_count);
                
                fprintf(stdout, "[s] COMMAND_SEND_MESSAGE[%s] %d bytes\n", uuid, payload_count);
            } break;
        }
    }
    
    close(socketfd);
}

static DECLARE_THREAD_FN(slave_thread)
{
    ponyint_thead_setname_actual("Flynn Slave #0");
        
    socklen_t len;
    int socketfd;
    struct sockaddr_in servaddr = {0};
    struct sockaddr_in clientaddr = {0};

    // socket create and verification
    socketfd = socket(AF_INET, SOCK_STREAM, 0);
    if (socketfd == -1) {
        fprintf(stderr, "Flynn Slave socket creation failed, exiting...\n");
        exit(1);
    }

    servaddr.sin_family = AF_INET;
    inet_pton(AF_INET, master_ip_address, &(servaddr.sin_addr));
    servaddr.sin_port = htons(master_tcp_port);
    
    if (connect(socketfd, (struct sockaddr*)&servaddr, sizeof(servaddr)) != 0) {
        printf("Flynn Slave connect to master failed, exiting...\n");
        exit(1);
    }
    
    slave_to_master_socketfd = socketfd;
    
    slave_read_from_master_thread(socketfd);
    
    close(socketfd);
    
    ponyint_pool_thread_cleanup();
    return 0;
}

void pony_slave(const char * address, int port) {
    if (pony_slave_is_connecting) { return; }
    
    pony_slave_is_connecting = true;
    
    strncpy(slave_ip_address, address, sizeof(slave_ip_address)-1);
    slave_tcp_port = port;
    
    ponyint_thread_create(&slave_tid, slave_thread, QOS_CLASS_BACKGROUND, NULL);

    
    fprintf(stderr, "pony_slave connect to %s:%d\n", address, port);
}

// MARK: - MESSAGES

void pony_remote_actor_send_message_to_slave(const char * actorUUID, const char * actorType, int * slaveID, const void * bytes, int count) {
    // Send the message to remote actor associated by actorUUID. On the master, there exists a
    // RemoteActor with this UUID (its the one we called the behavior on). When we send a message
    // to a slave, we send this UUID and the actor class name. If the actor doesn't exist there, then
    // it creates a new actor of that type there. It is THE MASTER'S RESPONSIBILITY to keep track of
    // which slave we have associated this particular actor UUID to ensure we always communicate with
    // the correct actor.
    
    // 0. The RemoteActor class on the Swift side inits slaveID to -1, to represent this is a remote
    // actor which has not been assigned to a slave yet.  If slaveID is < 0, then we need to round robin
    // pick a slave to create the paired actor on.
    
    uint8_t command = COMMAND_CREATE_ACTOR;
    send(temp_master_to_slave_socketfd, &command, 1, 0);
    uint8_t uuid_count = strlen(actorUUID);
    send(temp_master_to_slave_socketfd, &uuid_count, 1, 0);
    send(temp_master_to_slave_socketfd, actorUUID, uuid_count, 0);
    
    fprintf(stderr, "[%d] master writing to socket\n", temp_master_to_slave_socketfd);
}

void pony_remote_actor_send_message_to_master(const char * actorUUID, const void * bytes, int count) {
    // When a slave is sending back to a master, they send a message by knowing the recipients actor uuid
    // This is easier than sending to a client, because we know the receipient exists and where it is
}

// MARK: - SHUTDOWN

void pony_remote_shutdown() {
    if (pony_master_is_listening) {
        pony_master_is_listening = false;
        close(master_listen_socket);
        ponyint_thread_join(master_tid);
    }
    if (pony_slave_is_connecting) {
        pony_slave_is_connecting = false;
        close(slave_to_master_socketfd);
        ponyint_thread_join(slave_tid);
    }
}
