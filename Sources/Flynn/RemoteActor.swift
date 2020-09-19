import Foundation
import Pony

// swiftlint:disable line_length

// MARK: REMOTE ACTOR

public typealias RemoteBehavior = (Data) -> Data?
public typealias RemoteBehaviorReply = (Data) -> Void

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

public protocol BehaviorRegisterable {
    func unsafeRegisterAllBehaviors()
}

public typealias RemoteActor = ( InternalRemoteActor & BehaviorRegisterable )

open class InternalRemoteActor {

    public let unsafeUUID: String

    private var nodeSocketFD: Int32 = -1

    private var remoteBehaviors: [String: (Data) -> Data?] = [:]

    public required init() {
        unsafeUUID = UUID().uuidString
    }

    public required init(_ uuid: String) {
        unsafeUUID = uuid
    }

    public func unsafeIsConnected() -> Bool {
        return nodeSocketFD > 0
    }

    deinit {
        pony_remote_destroy_actor(unsafeUUID, &nodeSocketFD)
        //print("deinit - RemoteActor [\(nodeSocketFD)]")
    }

    public func safeRegisterRemoteBehavior(_ name: String, behavior: @escaping RemoteBehavior) {
        remoteBehaviors[name] = behavior
    }

    public func unsafeExecuteBehavior(_ name: String, _ payload: Data, _ replySocketFD: Int32) {
        if let behavior = remoteBehaviors[name] {
            if let data = behavior(payload) {
                data.withUnsafeBytes {
                    pony_remote_actor_send_message_to_root(replySocketFD,
                                                           unsafeUUID,
                                                           $0.baseAddress,
                                                           Int32(data.count))
                }
            }
        }
    }

    public func unsafeSendToRemote(_ actorType: String,
                                   _ behaviorType: String,
                                   _ jsonData: Data,
                                   _ sender: Actor?,
                                   _ callback: RemoteBehaviorReply?) {
        _ = jsonData.withUnsafeBytes {
            if let sender = sender, let callback = callback {
                RemoteActorManager.shared.beRegisterReply(unsafeUUID, sender, callback)
            }

            pony_remote_actor_send_message_to_node(unsafeUUID,
                                                   actorType,
                                                   behaviorType,
                                                   &nodeSocketFD,
                                                   $0.baseAddress,
                                                   Int32(jsonData.count))
        }
    }
}

// MARK: - REMOTE ACTOR RUNNER

// A pool of RemoteActorRunners is utilized by the RemoteActorManager to make use
// of all of the cores on a node for running behaviors of remote actors
public final class RemoteActorRunner: Actor {
    private func _beHandleMessage(_ actor: RemoteActor,
                                  _ behavior: String,
                                  _ data: Data,
                                  _ replySocketFD: Int32) {
        actor.unsafeExecuteBehavior(behavior, data, replySocketFD)
    }
}

// MARK: - REMOTE ACTOR MANAGER

// The RemoteActorManager is used both on the root and on the nodes
//
// On the root, it stores waiting replies for behaviors which return Data, and then executes
// those reply closures with the returned data.
//
// On the nodes, it:
// 1. Holds a registry of all RemoteActor classes by their class name as a string (beRegisterActorType)
// 2. Holds a reference to all actors which were created remotely at the behest of the root (beCreateActor/beDestroyActor)
// 3. Calls behaviors on said actors at the behest of the root (beHandleMessage)

public final class RemoteActorManager: Actor {
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

    private func _beRegisterActorType(_ actorType: RemoteActor.Type) {
        actorTypes[String(describing: actorType)] = actorType
    }

    private func _beCreateActor(_ actorUUID: String, _ actorType: String) {
        if let actorType = actorTypes[actorType] {
            let actor = actorType.init(actorUUID)
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

// MARK: - FLYNN EXTENSION / PONY SHIMS

private func nodeCreateActor(_ actorUUIDPtr: UnsafePointer<Int8>?, _ actorTypePtr: UnsafePointer<Int8>?) {
    guard let actorUUIDPtr = actorUUIDPtr else { return }
    guard let actorTypePtr = actorTypePtr else { return }

    RemoteActorManager.shared.beCreateActor(String(cString: actorUUIDPtr),
                                            String(cString: actorTypePtr))

}

private func nodeDestroyActor(_ actorUUIDPtr: UnsafePointer<Int8>?) {
    guard let actorUUIDPtr = actorUUIDPtr else { return }

    RemoteActorManager.shared.beDestroyActor(String(cString: actorUUIDPtr))
}

private func nodeHandleMessage(_ actorUUIDPtr: UnsafePointer<Int8>?,
                               _ behaviorPtr: UnsafePointer<Int8>?,
                               _ payload: AnyPtr,
                               _ payloadSize: Int32,
                               _ replySocketFD: Int32) {
    guard let actorUUIDPtr = actorUUIDPtr else { return }
    guard let behaviorPtr = behaviorPtr else { return }
    guard let payload = payload else { return }

    RemoteActorManager.shared.beHandleMessage(String(cString: actorUUIDPtr),
                                              String(cString: behaviorPtr),
                                              Data(bytesNoCopy: payload, count: Int(payloadSize), deallocator: .free),
                                              replySocketFD)
}

private func rootHandleMessageReply(_ actorUUIDPtr: UnsafePointer<Int8>?,
                                    _ payload: AnyPtr,
                                    _ payloadSize: Int32) {
    guard let actorUUIDPtr = actorUUIDPtr else { return }
    if let payload = payload {
        RemoteActorManager.shared.beHandleMessageReply(String(cString: actorUUIDPtr),
                                                       Data(bytesNoCopy: payload,
                                                            count: Int(payloadSize),
                                                            deallocator: .free))
    } else {
        RemoteActorManager.shared.beHandleMessageReply(String(cString: actorUUIDPtr), Data())
    }
}

extension Flynn {
    public class func root(_ address: String, _ port: Int32) {
        pony_root(address,
                    port,
                    rootHandleMessageReply)
    }

    public class func node(_ address: String, _ port: Int32, _ actorTypes: [RemoteActor.Type]) {
        Flynn.startup()

        pony_node(address,
                  port,
                  nodeCreateActor,
                  nodeDestroyActor,
                  nodeHandleMessage)

        for actorType in actorTypes {
            RemoteActorManager.shared.beRegisterActorType(actorType)
        }
    }
}

// MARK: - Autogenerated by FlynnLint
// Contents of file after this marker will be overwritten as needed

extension RemoteActorRunner {

    @discardableResult
    public func beHandleMessage(_ actor: RemoteActor,
                                _ behavior: String,
                                _ data: Data,
                                _ replySocketFD: Int32) -> Self {
        unsafeSend { self._beHandleMessage(actor, behavior, data, replySocketFD) }
        return self
    }

}

extension RemoteActorManager {

    @discardableResult
    public func beRegisterActorType(_ actorType: RemoteActor.Type) -> Self {
        unsafeSend { self._beRegisterActorType(actorType) }
        return self
    }
    @discardableResult
    public func beCreateActor(_ actorUUID: String,
                              _ actorType: String) -> Self {
        unsafeSend { self._beCreateActor(actorUUID, actorType) }
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
