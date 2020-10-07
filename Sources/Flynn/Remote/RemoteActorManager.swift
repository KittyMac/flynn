import Foundation
import Pony

// swiftlint:disable line_length

// MARK: REMOTE ACTOR

private class MessageReply {
    var actor: Actor
    var block: RemoteBehaviorReply

    init(_ actor: Actor, _ block: @escaping RemoteBehaviorReply) {
        self.actor = actor
        self.block = block
    }

    func run(_ data: Data) {
        actor.unsafeSend {
            self.block(data)
        }
    }
}

// The RemoteActorManager is used both on the root and on the nodes
//
// On the root, it stores waiting replies for behaviors which return Data, and then executes
// those reply closures with the returned data.
//
// On the nodes, it:
// 1. Holds a registry of all RemoteActor classes by their class name as a string (beRegisterActorType)
// 2. Holds a reference to all actors which were created remotely at the behest of the root (beCreateActor/beDestroyActor)
// 3. Calls behaviors on said actors at the behest of the root (beHandleMessage)

internal final class RemoteActorManager: Actor {
    static let shared = RemoteActorManager()
    private override init() {
        super.init()
        
        // To preserve causal messaging, we need to ensure that the behaviors for
        // a specific actor are always run on the same runner in the pool.
        if runnerPool.count == 0 {
            for _ in 0..<Flynn.cores {
                runnerPool.append(RemoteActorRunner())
            }
        }
    }

    // MARK: - RemoteActorManager: Node
    private var actorTypes: [String: RemoteActor.Type] = [:]
    private var actors: [String: RemoteActor] = [:]

    private var runnerPool: [RemoteActorRunner] = []

    private func _beGetActor(_ actorUUID: String) -> RemoteActor? {
        return actors[actorUUID]
    }

    private func _beRegisterActorType(_ actorType: RemoteActor.Type) {
        actorTypes[String(describing: actorType)] = actorType
    }

    private func _beRegisterActor(_ actor: RemoteActor) {
        actor.unsafeRegisterAllBehaviors()
        actors[actor.unsafeUUID] = actor
    }

    internal func unsafeRegisterActorsOnRoot(_ socketFD: Int32) {
        for actor in actors.values {
            let actorTypeWithModule = String(describing: actor)

            // actorType will contain the module name as the first part
            // ie: FlynnTests.Echo
            // For remote actor types, we ignore the module name and just
            // use the rest of the full path
            let actorType = actorTypeWithModule.components(separatedBy: ".").dropFirst().joined(separator: ".")

            // call into pony, send our actor UUIDs and type information over the supplied socket
            // (which is directly linked to a specific root node).
            pony_send_remote_actor_to_root(socketFD, actor.unsafeUUID, actorType)
        }
    }

    private func _beCreateActor(_ actorUUID: String,
                                _ actorType: String,
                                _ shouldBeProxy: Bool,
                                _ socketFD: Int32) {
        // Tricky: if we're on the root, then we want this to be a proxy. But if we're
        // on the node then we want it to be the real one
        
        
        if let actorType = actorTypes[actorType] {
            // If an actor exists and it is not a proxy, then we don't want to replace it with a proxy...
            if let existingActor = actors[actorUUID] {
                if existingActor.unsafeIsProxy == false {
                    return
                }
            }
            
            let actor = actorType.init(actorUUID, socketFD, shouldBeProxy)
            actor.unsafeRegisterAllBehaviors()
            actors[actorUUID] = actor
        }
    }

    private func _beDestroyActor(_ actorUUID: String) {
        actors.removeValue(forKey: actorUUID)
    }

    private func _beHandleMessage(_ actorUUID: String,
                                  _ behavior: String,
                                  _ data: Data,
                                  _ messageID: Int32,
                                  _ replySocketFD: Int32) {
        if let actor = actors[actorUUID] {
            unsafeGetRunnerForActor(actorUUID).beHandleMessage(actor, behavior, data, messageID, replySocketFD)
        }
    }
    
    internal func unsafeGetRunnerForActor(_ actorUUID: String) -> RemoteActorRunner {
        // Ok, this has pros and cons
        // pro: its quick, easy, and gaurantees causal messaging
        // con: we won't get amazing distribution across all cores
        let runnerIdx = abs(actorUUID.hashValue) % runnerPool.count
        return runnerPool[runnerIdx]
    }

    // MARK: - RemoteActorManager: Root

    private var waitingReplies: [Int32: MessageReply] = [:]

    private func _beRegisterReply(_ remoteActorUUID: String,
                                  _ messageID: Int32,
                                  _ actor: Actor,
                                  _ block: @escaping RemoteBehaviorReply) {
        waitingReplies[messageID] = MessageReply(actor, block)
    }

    private func _beHandleMessageReply(_ messageID: Int32,
                                       _ data: Data) {
        if let message = waitingReplies.removeValue(forKey: messageID) {
            message.run(data)
        }
    }
}

// MARK: - Autogenerated by FlynnLint
// Contents of file after this marker will be overwritten as needed

extension RemoteActorManager {

    @discardableResult
    public func beGetActor(_ actorUUID: String,
                           _ sender: Actor,
                           _ callback: @escaping ((RemoteActor?) -> Void)) -> Self {
        unsafeSend() {
            let result = self._beGetActor(actorUUID)
            sender.unsafeSend { callback(result) }
        }
        return self
    }
    @discardableResult
    public func beRegisterActorType(_ actorType: RemoteActor.Type) -> Self {
        unsafeSend { self._beRegisterActorType(actorType) }
        return self
    }
    @discardableResult
    public func beRegisterActor(_ actor: RemoteActor) -> Self {
        unsafeSend { self._beRegisterActor(actor) }
        return self
    }
    @discardableResult
    public func beCreateActor(_ actorUUID: String,
                              _ actorType: String,
                              _ shouldBeProxy: Bool,
                              _ socketFD: Int32) -> Self {
        unsafeSend { self._beCreateActor(actorUUID, actorType, shouldBeProxy, socketFD) }
        return self
    }
    @discardableResult
    public func beDestroyActor(_ actorUUID: String) -> Self {
        unsafeSend { self._beDestroyActor(actorUUID) }
        return self
    }
    @discardableResult
    public func beHandleMessage(_ actorUUID: String,
                                _ behavior: String,
                                _ data: Data,
                                _ messageID: Int32,
                                _ replySocketFD: Int32) -> Self {
        unsafeSend { self._beHandleMessage(actorUUID, behavior, data, messageID, replySocketFD) }
        return self
    }
    @discardableResult
    public func beRegisterReply(_ remoteActorUUID: String,
                                _ messageID: Int32,
                                _ actor: Actor,
                                _ block: @escaping RemoteBehaviorReply) -> Self {
        unsafeSend { self._beRegisterReply(remoteActorUUID, messageID, actor, block) }
        return self
    }
    @discardableResult
    public func beHandleMessageReply(_ messageID: Int32,
                                     _ data: Data) -> Self {
        unsafeSend { self._beHandleMessageReply(messageID, data) }
        return self
    }

}

extension RemoteActorRunner {


}
