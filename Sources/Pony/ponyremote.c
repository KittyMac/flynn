
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#include <stdlib.h>

#include "ponyrt.h"

#include "messageq.h"
#include "scheduler.h"
#include "actor.h"
#include "cpu.h"
#include "alloc.h"
#include "pool.h"

static bool pony_master_is_listening = false;
static bool pony_slave_is_connecting = false;

void pony_master(const char * address, int port) {
    if (pony_master_is_listening) { return; }
    
    fprintf(stderr, "pony_master listen on %s:%d\n", address, port);
}

void pony_slave(const char * address, int port) {
    if (pony_slave_is_connecting) { return; }
    
    fprintf(stderr, "pony_slave connect to %s:%d\n", address, port);
}

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
}

void pony_remote_actor_send_message_to_master(const char * actorUUID, const void * bytes, int count) {
    // When a slave is sending back to a master, they send a message by knowing the recipients actor uuid
    // This is easier than sending to a client, because we know the receipient exists and where it is
}
