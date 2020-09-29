
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

// MARK: - ROOT

static int number_of_nodes = 0;
static int number_of_cores = 0;

int ponyint_remote_nodes_count() {
    return number_of_nodes;
}

int ponyint_remote_core_count()
{
    return number_of_cores;
}

// Kept by the root to know which nodes are actively connected
typedef struct node_t
{
    int socketfd;
    pony_thread_id_t thread_tid;
    uint32_t core_count;
} node_t;

#define kMaxNodes 2048

static node_t nodes[kMaxNodes+1] = {0};

static bool inited = false;
static pthread_mutex_t nodes_mutex;

static pony_thread_id_t root_tid;
static char root_ip_address[128] = {0};
static int root_tcp_port = 9999;
static ReplyMessageFunc replyMessageFuncPtr = NULL;
static CreateActorFunc createActorFuncPtr = NULL;
static int root_listen_socket = -1;

static DECLARE_THREAD_FN(root_read_from_node_thread);

static void init_all_nodes() {
    node_t * ptr = nodes;
    while (ptr < (nodes + kMaxNodes)) {
        ptr->socketfd = -1;
        ptr++;
    }
}

static node_t * find_node_by_socket(int socketfd) {
    node_t * ptr = nodes;
    while (ptr < (nodes + kMaxNodes) && ptr->thread_tid != 0) {
        if (ptr->socketfd == socketfd) {
            return ptr;
        }
        ptr++;
    }
    return NULL;
}

static node_t * root_get_next_node() {
    static int next_node_index = 0;
    
    node_t * nodePtr = nodes + next_node_index;
    for (int i = 0; i < kMaxNodes; i++) {
        nodePtr++;
        if (nodePtr >= nodes + kMaxNodes) {
            nodePtr = nodes;
        }
        if (nodePtr->thread_tid != 0) {
            next_node_index = nodePtr - nodes;
            return nodePtr;
        }
    }
    
    return NULL;
}

static bool root_add_node(int socketfd) {
    pthread_mutex_lock(&nodes_mutex);
    for (int i = 0; i < kMaxNodes; i++) {
        if (nodes[i].thread_tid == 0) {
            disableSIGPIPE(socketfd);
            nodes[i].socketfd = socketfd;
            ponyint_thread_create(&nodes[i].thread_tid, root_read_from_node_thread, QOS_CLASS_BACKGROUND, nodes + i);
            number_of_nodes++;
            pthread_mutex_unlock(&nodes_mutex);
            return true;
        }
    }
    pthread_mutex_unlock(&nodes_mutex);
    return false;
}

static void root_remove_node(node_t * nodePtr) {
    if (nodePtr->thread_tid != 0) {
        pthread_mutex_lock(&nodes_mutex);
        number_of_cores -= nodePtr->core_count;
        number_of_nodes--;
        pthread_mutex_unlock(&nodes_mutex);
        
        close_socket(nodePtr->socketfd);
        ponyint_thread_join(nodePtr->thread_tid);
        
        pthread_mutex_lock(&nodes_mutex);
        nodePtr->thread_tid = 0;
        nodePtr->socketfd = -1;
        nodePtr->core_count = 0;
        pthread_mutex_unlock(&nodes_mutex);
    }
}

static void root_remove_all_nodes() {
    for (int i = 0; i < kMaxNodes; i++) {
        root_remove_node(nodes+i);
    }
}

static DECLARE_THREAD_FN(root_read_from_node_thread)
{
    // root reading information sent from node. The only valid command
    // node -> root is COMMAND_SEND_REPLY.  Any miscommunication from
    // the node results in the immediate termination of the connection
    node_t * nodePtr = (node_t *) arg;
    
    send_version_check(nodePtr->socketfd);
    
    while(nodePtr->socketfd >= 0) {
        
#if REMOTE_DEBUG
        fprintf(stderr, "[%d] root reading socket\n", nodePtr->socketfd);
#endif
        
        // read the command byte
        uint8_t command = read_command(nodePtr->socketfd);
        if (command != COMMAND_VERSION_CHECK &&
            command != COMMAND_CORE_COUNT &&
            command != COMMAND_HEARTBEAT &&
            command != COMMAND_CREATE_ACTOR &&
            command != COMMAND_SEND_REPLY) {
            root_remove_node(nodePtr);
            return 0;
        }
        
        // read the size of the uuid
        char uuid[128] = {0};
        if (command == COMMAND_VERSION_CHECK ||
            command == COMMAND_CREATE_ACTOR) {
            if (!read_bytecount_buffer(nodePtr->socketfd, uuid, sizeof(uuid)-1)) {
                root_remove_node(nodePtr);
                return 0;
            }
        }
        
        switch(command) {
            case COMMAND_VERSION_CHECK: {
                if (strncmp(BUILD_VERSION_UUID, uuid, strlen(BUILD_VERSION_UUID)) != 0) {
                    fprintf(stdout, "warning: root -> node version mismatch ( [%s] != [%s] )\n", uuid, BUILD_VERSION_UUID);
                }
            } break;
            case COMMAND_CREATE_ACTOR: {
                char type[128] = {0};
                if (!read_bytecount_buffer(nodePtr->socketfd, type, sizeof(type)-1)) {
                    root_remove_node(nodePtr);
                    ponyint_pool_thread_cleanup();
                    return 0;
                }
                
                createActorFuncPtr(uuid, type, nodePtr->socketfd);
                
#if REMOTE_DEBUG
                fprintf(stdout, "[%d] COMMAND_CREATE_ACTOR(root)[%s, %s]\n", nodePtr->socketfd, uuid, type);
#endif
            } break;
            case COMMAND_CORE_COUNT: {
                uint32_t core_count = 0;
                recvall(nodePtr->socketfd, &core_count, sizeof(core_count));
                core_count = ntohl(core_count);
                
                pthread_mutex_lock(&nodes_mutex);
                number_of_cores = number_of_cores - nodePtr->core_count + core_count;
                pthread_mutex_unlock(&nodes_mutex);

                nodePtr->core_count = core_count;
                
            } break;
            case COMMAND_SEND_REPLY: {
                uint32_t messageID = 0;
                if (!read_int(nodePtr->socketfd, &messageID)) {
                    root_remove_node(nodePtr);
                    ponyint_pool_thread_cleanup();
                    return 0;
                }
                
                uint32_t payload_count = 0;
                char * payload = read_intcount_buffer(nodePtr->socketfd, &payload_count);
                replyMessageFuncPtr(messageID, payload, payload_count);
                
#if REMOTE_DEBUG
                fprintf(stdout, "[%d] COMMAND_SEND_REPLY[%s] %d bytes\n", nodePtr->socketfd, uuid, payload_count);
#endif
            } break;
        }
    }
    
    root_remove_node(nodePtr);
    
    return 0;
}

static DECLARE_THREAD_FN(root_thread)
{
    ponyint_thead_setname_actual("Flynn Root #0");
        
    socklen_t len;
    int socketfd, connectionfd;
    struct sockaddr_in servaddr = {0};
    struct sockaddr_in clientaddr = {0};

    // socket create and verification
    socketfd = socket(AF_INET, SOCK_STREAM, 0);
    if (socketfd < 0) {
        fprintf(stderr, "Flynn Root socket creation failed, exiting...\n");
        exit(1);
    }
    
    disableSIGPIPE(socketfd);
    
    root_listen_socket = socketfd;

    servaddr.sin_family = AF_INET;
    inet_pton(AF_INET, root_ip_address, &(servaddr.sin_addr));
    servaddr.sin_port = htons(root_tcp_port);
    
    if ((bind(socketfd, (struct sockaddr *)&servaddr, sizeof(servaddr))) != 0) {
        close_socket(socketfd);
        perror("Flynn Root socket bind failed, exiting. Error");
        exit(1);
    }
    
#if REMOTE_DEBUG
    fprintf(stderr, "[%d] root listen socket\n", root_listen_socket);
#endif
    while(root_listen_socket >= 0) {
        if ((listen(socketfd, 32)) != 0) {
            fprintf(stderr, "Flynn Root socket listen failed, ending root listen thread\n");
            close_socket(socketfd);
            ponyint_pool_thread_cleanup();
            return 0;
        }
        
        connectionfd = accept(socketfd, (struct sockaddr*)&clientaddr, &len);
        if (connectionfd < 0) {
            fprintf(stderr, "Flynn Root failed to accept incoming connection, skipping...\n");
            continue;
        }
        
        if(!root_add_node(connectionfd)) {
            fprintf(stderr, "Flynn Root failed to add node, maximum number of nodes exceeded\n");
            close_socket(socketfd);
            ponyint_pool_thread_cleanup();
            return 0;
        }
    }
    
    close_socket(socketfd);
    ponyint_pool_thread_cleanup();
    return 0;
}

void pony_root(const char * address,
               int port,
               CreateActorFunc createActorFunc,
               ReplyMessageFunc replyFunc) {
    if (root_listen_socket >= 0) { return; }
    
    if (!inited) {
        inited = true;
        pthread_mutex_init(&nodes_mutex, NULL);
        init_all_nodes();
    }
    
    replyMessageFuncPtr = replyFunc;
    createActorFuncPtr = createActorFunc;
    
    strncpy(root_ip_address, address, sizeof(root_ip_address)-1);
    root_tcp_port = port;
    
    ponyint_thread_create(&root_tid, root_thread, QOS_CLASS_BACKGROUND, NULL);
}

void root_shutdown() {
    close_socket(root_listen_socket);
    root_listen_socket = -1;
    ponyint_thread_join(root_tid);
    
    root_remove_all_nodes();
    
    number_of_nodes = 0;
    number_of_cores = 0;
}


// MARK: - MESSAGES

static uint32_t messageID = 1;

int pony_remote_actor_send_message_to_node(const char * actorUUID, const char * actorType, const char * behaviorType, int * nodeSocketFD, const void * bytes, int count) {
    
    // Note: this is not optimal; we should have a mutext per socket
    pthread_mutex_lock(&nodes_mutex);
    
    if (*nodeSocketFD < 0) {
        node_t * nodePtr = root_get_next_node();
        if (nodePtr == NULL) {
            fprintf(stderr, "error: RemoteActor behavior called but no nodes are connected to root\n");
            pthread_mutex_unlock(&nodes_mutex);
            return 0;
        }
        *nodeSocketFD = nodePtr->socketfd;
        send_create_actor(*nodeSocketFD, actorUUID, actorType);
    }
    
    messageID += 1;
    
    if (send_message(*nodeSocketFD, messageID, actorUUID, behaviorType, bytes, count) < 0) {
        // we lost connection with this remote actor
        *nodeSocketFD = -1;
    }
    
    pthread_mutex_unlock(&nodes_mutex);
    
    return messageID;
}

void pony_remote_destroy_actor(const char * actorUUID, int * nodeSocketFD) {
    if (*nodeSocketFD >= 0) {
        node_t * ptr = find_node_by_socket(*nodeSocketFD);
        if (ptr != NULL) {
            send_destroy_actor(ptr->socketfd, actorUUID);
        }
    }
}
