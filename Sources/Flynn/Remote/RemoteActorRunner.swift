import Foundation
import Pony

// A pool of RemoteActorRunners is utilized by the RemoteActorManager to make use
// of all of the cores on a node for running behaviors of remote actors
public final class RemoteActorRunner: Actor {
    
    @inlinable
    internal func _beHandleMessage(_ actor: RemoteActor,
                                   _ behavior: String,
                                   _ data: Data,
                                   _ messageID: Int32,
                                   _ replySocketFD: Int32) {
        actor.unsafeExecuteBehavior(behavior, data, messageID, replySocketFD)
    }
}
