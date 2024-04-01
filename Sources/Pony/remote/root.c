
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
#include "../memory.h"

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
    pony_thread_id_t read_thread_tid;
    pony_thread_id_t write_thread_tid;
    uint32_t core_count;
    uint32_t active_actors;
    messageq_t write_queue;
} node_t;

#define kMaxNodes 2048

static node_t nodes[kMaxNodes+1] = {0};


static bool inited = false;
static PONY_MUTEX * nodes_mutex;
static PONY_MUTEX * messageId_mutex;

static pony_thread_id_t root_tid;
static char root_ip_address[128] = {0};
static int root_tcp_port = 9999;
static ReplyMessageFunc replyMessageFuncPtr = NULL;
static CreateActorFunc createActorFuncPtr = NULL;
static RegisterWithRootFunc registerWithRootPtr = NULL;
static NodeDisconnectedFunc nodeDisconnectedPtr = NULL;
static int root_listen_socket = -1;

static DECLARE_THREAD_FN(root_write_to_node_thread);
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
    while (ptr < (nodes + kMaxNodes)) {
        if (ptr->socketfd == socketfd && ptr->read_thread_tid != 0) {
            return ptr;
        }
        ptr++;
    }
    return NULL;
}

static node_t * root_get_next_node() {
    static int next_node_index = 0;
    
    ponyint_mutex_lock(nodes_mutex);
    node_t * nodePtr = nodes + next_node_index;
    for (int i = 0; i < kMaxNodes; i++) {
        nodePtr++;
        if (nodePtr >= nodes + kMaxNodes) {
            nodePtr = nodes;
        }
        if (nodePtr->read_thread_tid != 0) {
            next_node_index = (int)(nodePtr - nodes);
            
            ponyint_mutex_unlock(nodes_mutex);
            return nodePtr;
        }
    }
    ponyint_mutex_unlock(nodes_mutex);
    return NULL;
}

int ponyint_remote_core_count_by_socket(int socketfd)
{
    node_t * nodePtr = find_node_by_socket(socketfd);
    if (nodePtr != NULL) {
        return nodePtr->core_count;
    }
    return 0;
}

static bool root_add_node(int socketfd) {
    ponyint_mutex_lock(nodes_mutex);
    for (int i = 0; i < kMaxNodes; i++) {
        if (nodes[i].read_thread_tid == 0) {
            disableSIGPIPE(socketfd);
            nodes[i].socketfd = socketfd;
            ponyint_messageq_init(&nodes[i].write_queue);
            ponyint_thread_create(&nodes[i].read_thread_tid, root_read_from_node_thread, QOS_CLASS_UTILITY, nodes + i);
            ponyint_thread_create(&nodes[i].write_thread_tid, root_write_to_node_thread, QOS_CLASS_UTILITY, nodes + i);
            number_of_nodes++;
            ponyint_mutex_unlock(nodes_mutex);
            return true;
        }
    }
    ponyint_mutex_unlock(nodes_mutex);
    return false;
}

static void root_remove_node(node_t * nodePtr) {
    ponyint_mutex_lock(nodes_mutex);
    if (nodePtr->read_thread_tid != 0) {
        number_of_cores -= nodePtr->core_count;
        number_of_nodes--;
        
        int socketfd = nodePtr->socketfd;
        nodePtr->socketfd = -1;
        nodePtr->read_thread_tid = 0;
        nodePtr->write_thread_tid = 0;
        nodePtr->core_count = 0;
        nodePtr->active_actors = 0;
        
        // ensure everyone else is done writing to the queue
        pony_msg_t* head = NULL;
        do {
            head = atomic_load_explicit(&nodePtr->write_queue.head, memory_order_relaxed);
        } while(((uintptr_t)head & (uintptr_t)1) != (uintptr_t)1);
        atomic_thread_fence(memory_order_acquire);
        
        ponyint_messageq_destroy(&nodePtr->write_queue);
        
        nodeDisconnectedPtr(socketfd);
    }
    ponyint_mutex_unlock(nodes_mutex);
}

static void root_remove_all_nodes() {
    if (inited == false) {
        return;
    }
    
    // we just invalidate all sockets, the nodes will remove themselves
    for (int i = 0; i < kMaxNodes; i++) {
        ponyint_mutex_lock(nodes_mutex);
        pony_thread_id_t write_thread_tid = nodes[i].write_thread_tid;
        pony_thread_id_t read_thread_tid = nodes[i].read_thread_tid;
        close_socket(nodes[i].socketfd);
        nodes[i].socketfd = -1;
        ponyint_mutex_unlock(nodes_mutex);
        
        if (write_thread_tid != 0) {
            ponyint_thread_join(write_thread_tid);
        }
        if (read_thread_tid != 0) {
            ponyint_thread_join(read_thread_tid);
        }
    }
}

void pony_root_send_version_check(node_t * nodePtr)
{
    pony_msg_remote_version_t* m = (pony_msg_remote_version_t*)pony_alloc_msg(sizeof(pony_msg_remote_version_t), kRemote_Version);
    ponyint_actor_messageq_push(&nodePtr->write_queue, &m->msg, &m->msg);
}

void pony_root_send_create_actor(node_t * nodePtr, const char * actorUUID, const char * actorType)
{
    pony_msg_remote_createactor_t* m = (pony_msg_remote_createactor_t*)pony_alloc_msg(sizeof(pony_msg_remote_createactor_t), kRemote_CreateActor);
    strncpy(m->actorUUID, actorUUID, sizeof(m->actorUUID)-1);
    strncpy(m->actorType, actorType, sizeof(m->actorType)-1);
    ponyint_actor_messageq_push(&nodePtr->write_queue, &m->msg, &m->msg);
}

void pony_root_send_destroy_actor(node_t * nodePtr, const char * actorUUID)
{
    pony_msg_remote_destroyactor_t* m = (pony_msg_remote_destroyactor_t*)pony_alloc_msg(sizeof(pony_msg_remote_destroyactor_t), kRemote_DestroyActor);
    strncpy(m->actorUUID, actorUUID, sizeof(m->actorUUID)-1);
    ponyint_actor_messageq_push(&nodePtr->write_queue, &m->msg, &m->msg);
}

void pony_root_send_message(node_t * nodePtr,
                            uint32_t messageId,
                            const char * actorUUID,
                            const char * behaviorType,
                            const void * payload,
                            uint32_t length)
{
    pony_msg_remote_sendmessage_t* m = (pony_msg_remote_sendmessage_t*)pony_alloc_msg(sizeof(pony_msg_remote_sendmessage_t), kRemote_SendMessage);
    m->messageId = messageId;
    strncpy(m->actorUUID, actorUUID, sizeof(m->actorUUID)-1);
    strncpy(m->behaviorType, behaviorType, sizeof(m->behaviorType)-1);
    
    m->payload = (void *)malloc(length);
    memcpy(m->payload, payload, length);
    m->length = length;
    ponyint_actor_messageq_push(&nodePtr->write_queue, &m->msg, &m->msg);
}

static DECLARE_THREAD_FN(root_write_to_node_thread)
{
    ponyint_thead_setname_actual("Flynn Root -> Node");
    
    extern void send_version_check(int socketfd);
    extern void send_create_actor(int socketfd, const char * actorUUID, const char * actorType);
    extern void send_destroy_actor(int socketfd, const char * actorUUID);
    extern int send_message(int socketfd, int messageID, const char * actorUUID, const char * behaviorType, const void * bytes, uint32_t count);
    
    // root writing information to be sent to the node. Uses pony message
    // queue to allow other threads to add messages to the queue, and this
    // just drains the queue and writes to the socket
    node_t * nodePtr = (node_t *) arg;
    pony_msg_t* msg;
        
    while(nodePtr->socketfd >= 0) {
        
        bool didSend = false;
        
        while((msg = (pony_msg_t *)ponyint_actor_messageq_pop(&nodePtr->write_queue)) != NULL) {
            
            if (didSend == false) {
                didSend = true;
                cork(nodePtr->socketfd);
            }
            
            switch(msg->msgId) {
                case kRemote_Version: {
                    send_version_check(nodePtr->socketfd);
                } break;
                case kRemote_CreateActor: {
                    pony_msg_remote_createactor_t * m = (pony_msg_remote_createactor_t *)msg;
                    send_create_actor(nodePtr->socketfd, m->actorUUID, m->actorType);
                } break;
                case kRemote_DestroyActor: {
                    pony_msg_remote_destroyactor_t * m = (pony_msg_remote_destroyactor_t *)msg;
                    send_destroy_actor(nodePtr->socketfd, m->actorUUID);
                } break;
                case kRemote_SendMessage: {
                    pony_msg_remote_sendmessage_t * m = (pony_msg_remote_sendmessage_t *)msg;
                    
                    send_message(nodePtr->socketfd,
                                 m->messageId,
                                 m->actorUUID,
                                 m->behaviorType,
                                 m->payload,
                                 m->length);
                    free(m->payload);
                } break;
            }
            
            ponyint_actor_messageq_pop_mark_done(&nodePtr->write_queue);
        }
        
        if (didSend) {
            uncork(nodePtr->socketfd);
        }
        
        ponyint_messageq_markempty(&nodePtr->write_queue);
        usleep(500);
    }
    
    ponyint_pool_thread_cleanup();
    return 0;
}

static DECLARE_THREAD_FN(root_read_from_node_thread)
{
    ponyint_thead_setname_actual("Flynn Root <- Node");
    
    // root reading information sent from node. The only valid command
    // node -> root is COMMAND_SEND_REPLY.  Any miscommunication from
    // the node results in the immediate termination of the connection
    node_t * nodePtr = (node_t *) arg;
    
    pony_root_send_version_check(nodePtr);
    
    // set the 11 second timeout on reads from the node. If we timeout, then
    // the node missed 2 of its heartbeats and we should disconnect from it
    struct timeval timeout;
    timeout.tv_sec = 11;
    timeout.tv_usec = 0;
    setsockopt (nodePtr->socketfd, SOL_SOCKET, SO_RCVTIMEO, (char *)&timeout, sizeof(timeout));
        
    while(nodePtr->socketfd >= 0) {
        
#if REMOTE_DEBUG
        pony_syslog2("Flynn", "[%d] root reading socket\n", nodePtr->socketfd);
#endif
        
        // read the command byte
        uint8_t command = read_command(nodePtr->socketfd);
        if (command == COMMAND_NULL) {
            // If we timeout then we should disconnect from the node (it missed two heartbeats)
            pony_syslog2("Flynn", "warning: dropped connection to node [%d]\n", nodePtr->socketfd);
            root_remove_node(nodePtr);
            ponyint_pool_thread_cleanup();
            return 0;
        }
        
        if (command != COMMAND_VERSION_CHECK &&
            command != COMMAND_CORE_COUNT &&
            command != COMMAND_HEARTBEAT &&
            command != COMMAND_CREATE_ACTOR &&
            command != COMMAND_REGISTER_WITH_ROOT &&
            command != COMMAND_SEND_REPLY &&
            command != COMMAND_DESTROY_ACTOR_ACK) {
            root_remove_node(nodePtr);
            ponyint_pool_thread_cleanup();
            return 0;
        }
        
        // read the size of the uuid
        char uuid[128] = {0};
        if (command == COMMAND_VERSION_CHECK ||
            command == COMMAND_CREATE_ACTOR) {
            if (!read_bytecount_buffer(nodePtr->socketfd, uuid, sizeof(uuid)-1)) {
                root_remove_node(nodePtr);
                ponyint_pool_thread_cleanup();
                return 0;
            }
        }
        
        switch(command) {
            case COMMAND_VERSION_CHECK: {
                if (strncmp(BUILD_VERSION_UUID, uuid, strlen(BUILD_VERSION_UUID)) != 0) {
                    pony_syslog2("Flynn", "warning: root -> node version mismatch ( [%s] != [%s] )\n", uuid, BUILD_VERSION_UUID);
                }
            } break;
            case COMMAND_DESTROY_ACTOR_ACK: {
                ponyint_mutex_lock(nodes_mutex);
                if (nodePtr->active_actors > 0) {
                    nodePtr->active_actors -= 1;
                } else {
                    assert(false);
                }
                ponyint_mutex_unlock(nodes_mutex);
            } break;
            case COMMAND_REGISTER_WITH_ROOT: {
                uint32_t payload_count = 0;
                char * payload = read_intcount_buffer(nodePtr->socketfd, &payload_count);
                registerWithRootPtr(payload, nodePtr->socketfd);
                free(payload);
#if REMOTE_DEBUG
                pony_syslog2("Flynn", "[%d] COMMAND_REGISTER_WITH_ROOT(root)[%s]\n", nodePtr->socketfd, uuid);
#endif
            } break;
            case COMMAND_CREATE_ACTOR: {
                char type[128] = {0};
                if (!read_bytecount_buffer(nodePtr->socketfd, type, sizeof(type)-1)) {
                    root_remove_node(nodePtr);
                    ponyint_pool_thread_cleanup();
                    return 0;
                }
                
                createActorFuncPtr(uuid, type, true, nodePtr->socketfd);
                
#if REMOTE_DEBUG
                pony_syslog2("Flynn", "[%d] COMMAND_CREATE_ACTOR(root)[%s, %s]\n", nodePtr->socketfd, uuid, type);
#endif
            } break;
            case COMMAND_CORE_COUNT: {
                uint32_t core_count = 0;
                recvall(nodePtr->socketfd, &core_count, sizeof(core_count));
                core_count = ntohl(core_count);
                
                ponyint_mutex_lock(nodes_mutex);
                number_of_cores = number_of_cores - nodePtr->core_count + core_count;
                ponyint_mutex_unlock(nodes_mutex);

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
                pony_syslog2("Flynn", "[%d] COMMAND_SEND_REPLY[%s] %d bytes\n", nodePtr->socketfd, uuid, payload_count);
#endif
            } break;
        }
    }
    
    root_remove_node(nodePtr);
    ponyint_pool_thread_cleanup();
    return 0;
}

static DECLARE_THREAD_FN(root_thread)
{
    ponyint_thead_setname_actual("Flynn Root");
        
    socklen_t len;
    int socketfd, connectionfd;
    struct sockaddr_in servaddr = {0};
    struct sockaddr_in clientaddr = {0};

    // socket create and verification
    socketfd = socket(AF_INET, SOCK_STREAM, 0);
    if (socketfd < 0) {
        pony_syslog2("Flynn", "Flynn Root socket creation failed, exiting...\n");
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
    pony_syslog2("Flynn", "[%d] root listen socket\n", root_listen_socket);
#endif
    while(root_listen_socket >= 0) {
        if ((listen(socketfd, 32)) != 0) {
            pony_syslog2("Flynn", "Flynn Root socket listen failed, ending root listen thread\n");
            close_socket(socketfd);
            ponyint_pool_thread_cleanup();
            return 0;
        }
        
        connectionfd = accept(socketfd, (struct sockaddr*)&clientaddr, &len);
        if (connectionfd < 0) {
            pony_syslog2("Flynn", "Flynn Root failed to accept incoming connection, skipping...\n");
            continue;
        }
        
        if(!root_add_node(connectionfd)) {
            pony_syslog2("Flynn", "Flynn Root failed to add node, maximum number of nodes exceeded\n");
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
               RegisterWithRootFunc registerWithRoot,
               CreateActorFunc createActorFunc,
               ReplyMessageFunc replyFunc,
               NodeDisconnectedFunc nodeDisconnected) {
    if (root_listen_socket >= 0) { return; }
    
    if (!inited) {
        inited = true;
        nodes_mutex = ponyint_mutex_create();
        messageId_mutex = ponyint_mutex_create();
        init_all_nodes();
    }
    
    replyMessageFuncPtr = replyFunc;
    createActorFuncPtr = createActorFunc;
    registerWithRootPtr = registerWithRoot;
    nodeDisconnectedPtr = nodeDisconnected;
    
    strncpy(root_ip_address, address, sizeof(root_ip_address)-1);
    root_tcp_port = port;
    
    ponyint_thread_create(&root_tid, root_thread, QOS_CLASS_UTILITY, NULL);
}

void root_shutdown() {
    close_socket(root_listen_socket);
    root_listen_socket = -1;
    ponyint_thread_join(root_tid);
    
    root_remove_all_nodes();
    
    number_of_nodes = 0;
    number_of_cores = 0;
}

int pony_root_num_active_remotes() {
    node_t * ptr = nodes;
    int total = 0;
    while (ptr < (nodes + kMaxNodes)) {
        total += ptr->active_actors;
        ptr++;
    }
    return total;
}


// MARK: - MESSAGES

int pony_next_messageId() {
    static uint32_t messageID = 1;
    ponyint_mutex_lock(messageId_mutex);
    messageID += 1;
    if (messageID < 0) {
        messageID = 1;
    }
    ponyint_mutex_unlock(messageId_mutex);
    return messageID;
}

int pony_root_send_actor_message_to_node(const char * actorUUID,
                                         const char * actorType,
                                         const char * behaviorType,
                                         bool actorNeedsCreated,
                                         int nodeSocketFD,
                                         const void * bytes,
                                         int count) {
    if (nodeSocketFD < 0) {
        return -1;
    }
    
    ponyint_mutex_lock(nodes_mutex);
    
    node_t * nodePtr = find_node_by_socket(nodeSocketFD);
    if (nodePtr == NULL) {
        ponyint_mutex_unlock(nodes_mutex);
        return -1;
    }
    
    if (actorNeedsCreated) {
        nodePtr->active_actors += 1;
        pony_root_send_create_actor(nodePtr, actorUUID, actorType);
    }
    
    uint32_t messageId = pony_next_messageId();
    
    pony_root_send_message(nodePtr,
                           messageId,
                           actorUUID,
                           behaviorType,
                           bytes,
                           count);
    
    ponyint_mutex_unlock(nodes_mutex);
    
    return messageId;
}

void pony_root_destroy_actor_to_node(const char * actorUUID, int nodeSocketFD) {
    if (nodeSocketFD >= 0) {
        ponyint_mutex_lock(nodes_mutex);
        node_t * nodePtr = find_node_by_socket(nodeSocketFD);
        if (nodePtr != NULL) {
            pony_root_send_destroy_actor(nodePtr, actorUUID);
        }
        ponyint_mutex_unlock(nodes_mutex);
    }
}
