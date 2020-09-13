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

public protocol Registerable {
    func unsafeRegisterAllBehaviors()
}

public typealias RemoteActor = ( InternalRemoteActor & Registerable )

open class InternalRemoteActor {

    public let unsafeUUID: String

    private var slaveSocketFD: Int32 = -1

    private var remoteBehaviors: [String: (Data) -> Data?] = [:]

    public required init() {
        unsafeUUID = UUID().uuidString
    }

    public required init(_ uuid: String) {
        unsafeUUID = uuid
    }

    deinit {
        pony_remote_destroy_actor(unsafeUUID, &slaveSocketFD)
        //print("deinit - RemoteActor [\(slaveSocketFD)]")
    }

    public func safeRegisterRemoteBehavior(_ name: String, behavior: @escaping RemoteBehavior) {
        remoteBehaviors[name] = behavior
    }

    public func unsafeExecuteBehavior(_ name: String, _ payload: Data, _ replySocketFD: Int32) {
        if let behavior = remoteBehaviors[name] {
            if let data = behavior(payload) {
                data.withUnsafeBytes {
                    pony_remote_actor_send_message_to_master(replySocketFD,
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

            pony_remote_actor_send_message_to_slave(unsafeUUID,
                                                    actorType,
                                                    behaviorType,
                                                    &slaveSocketFD,
                                                    $0.baseAddress,
                                                    Int32(jsonData.count))
        }
    }
}

// MARK: - REMOTE ACTOR MANAGER

public final class RemoteActorManager: Actor {
    static let shared = RemoteActorManager()
    private override init() {}

    private var actorTypes: [String: RemoteActor.Type] = [:]
    private var actors: [String: RemoteActor] = [:]
    private var waitingReply: [String: Queue<MessageReply>] = [:]

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
            actor.unsafeExecuteBehavior(behavior, data, replySocketFD)
        }
    }

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
        }
    }
}

// MARK: - FLYNN EXTENSION / PONY SHIMS

private func slaveCreateActor(_ actorUUIDPtr: UnsafePointer<Int8>?, _ actorTypePtr: UnsafePointer<Int8>?) {
    guard let actorUUIDPtr = actorUUIDPtr else { return }
    guard let actorTypePtr = actorTypePtr else { return }

    RemoteActorManager.shared.beCreateActor(String(cString: actorUUIDPtr),
                                            String(cString: actorTypePtr))

}

private func slaveDestroyActor(_ actorUUIDPtr: UnsafePointer<Int8>?) {
    guard let actorUUIDPtr = actorUUIDPtr else { return }

    RemoteActorManager.shared.beDestroyActor(String(cString: actorUUIDPtr))
}

private func slaveHandleMessage(_ actorUUIDPtr: UnsafePointer<Int8>?,
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

private func masterHandleMessageReply(_ actorUUIDPtr: UnsafePointer<Int8>?,
                                      _ payload: AnyPtr,
                                      _ payloadSize: Int32) {
    guard let actorUUIDPtr = actorUUIDPtr else { return }
    guard let payload = payload else { return }

    RemoteActorManager.shared.beHandleMessageReply(String(cString: actorUUIDPtr),
                                                   Data(bytesNoCopy: payload,
                                                        count: Int(payloadSize),
                                                        deallocator: .free))
}

extension Flynn {
    public class func master(_ address: String, _ port: Int32) {
        pony_master(address,
                    port,
                    masterHandleMessageReply)
    }

    public class func slave(_ address: String, _ port: Int32, _ actorTypes: [RemoteActor.Type]) {
        pony_slave(address,
                   port,
                   slaveCreateActor,
                   slaveDestroyActor,
                   slaveHandleMessage)

        for actorType in actorTypes {
            RemoteActorManager.shared.beRegisterActorType(actorType)
        }
    }
}

// MARK: - Autogenerated by FlynnLint
// Contents of file after this marker will be overwritten as needed

extension RemoteActorManager {

    @discardableResult
    public func beRegisterActorType(_ actorType: RemoteActor.Type) -> Self {
        unsafeSend { self._beRegisterActorType(actorType) }
        return self
    }
    @discardableResult
    public func beCreateActor(_ actorUUID: String, _ actorType: String) -> Self {
        unsafeSend { self._beCreateActor(actorUUID, actorType) }
        return self
    }
    @discardableResult
    public func beDestroyActor(_ actorUUID: String) -> Self {
        unsafeSend { self._beDestroyActor(actorUUID) }
        return self
    }
    @discardableResult
    public func beHandleMessage(_ actorUUID: String, _ behavior: String, _ data: Data, _ replySocketFD: Int32) -> Self {
        unsafeSend { self._beHandleMessage(actorUUID, behavior, data, replySocketFD) }
        return self
    }
    @discardableResult
    public func beRegisterReply(_ remoteActorUUID: String, _ actor: Actor, _ block: @escaping RemoteBehaviorReply) -> Self {
        unsafeSend { self._beRegisterReply(remoteActorUUID, actor, block) }
        return self
    }
    @discardableResult
    public func beHandleMessageReply(_ remoteActorUUID: String, _ data: Data) -> Self {
        unsafeSend { self._beHandleMessageReply(remoteActorUUID, data) }
        return self
    }

}
