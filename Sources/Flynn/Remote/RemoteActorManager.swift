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

        for _ in 0..<Flynn.cores {
            runnerPool.append(RemoteActorRunner())
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

    public func unsafeRegisterActorsOnRoot(_ socketFD: Int32) {
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
                                _ socketFD: Int32) {
        if let actorType = actorTypes[actorType] {
            let actor = actorType.init(actorUUID, socketFD)
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
                                  _ replySocketFD: Int32) {
        if let actor = actors[actorUUID] {
            // To preserve causal messaging, we need to ensure that the behaviors for
            // a specific actor are always run on the same runner in the pool.

            // Ok, this has pros and cons
            // pro: its quick, easy, and gaurantees causal messaging
            // con: we won't get amazing distribution across all cores
            let runnerIdx = abs(actorUUID.hashValue) % runnerPool.count
            runnerPool[runnerIdx].beHandleMessage(actor, behavior, data, replySocketFD)
        }
    }

    // MARK: - RemoteActorManager: Root

    private var waitingReply: [String: Queue<MessageReply>] = [:]

    private func _beRegisterReply(_ remoteActorUUID: String,
                                  _ actor: Actor,
                                  _ block: @escaping RemoteBehaviorReply) {
        let msg = MessageReply(actor, block)

        if let messages = waitingReply[remoteActorUUID] {
            messages.enqueue(msg)
        } else {
            let messages = Queue<MessageReply>(size: 512,
                                               manyProducers: false,
                                               manyConsumers: false)
            messages.enqueue(msg)
            waitingReply[remoteActorUUID] = messages
        }
    }

    private func _beHandleMessageReply(_ remoteActorUUID: String,
                                       _ data: Data) {
        if let messages = waitingReply[remoteActorUUID] {
            if let message = messages.dequeue() {
                message.run(data)
            }

            if messages.isEmpty {
                waitingReply.removeValue(forKey: remoteActorUUID)
            }
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
        unsafeSend {
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
                              _ socketFD: Int32) -> Self {
        unsafeSend { self._beCreateActor(actorUUID, actorType, socketFD) }
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
                                _ replySocketFD: Int32) -> Self {
        unsafeSend { self._beHandleMessage(actorUUID, behavior, data, replySocketFD) }
        return self
    }
    @discardableResult
    public func beRegisterReply(_ remoteActorUUID: String,
                                _ actor: Actor,
                                _ block: @escaping RemoteBehaviorReply) -> Self {
        unsafeSend { self._beRegisterReply(remoteActorUUID, actor, block) }
        return self
    }
    @discardableResult
    public func beHandleMessageReply(_ remoteActorUUID: String,
                                     _ data: Data) -> Self {
        unsafeSend { self._beHandleMessageReply(remoteActorUUID, data) }
        return self
    }

}

extension RemoteActorRunner {

}
