import Foundation
import Pony

public typealias RemoteBehavior = (Data) -> Data?
public typealias RemoteBehaviorReply = (Data) -> Void

public protocol BehaviorRegisterable {
    func unsafeRegisterAllBehaviors()
}

public typealias RemoteActor = ( InternalRemoteActor & BehaviorRegisterable )

open class InternalRemoteActor {

    public let unsafeUUID: String
    private let isNamedService: Bool

    private var nodeSocketFD: Int32 = -1

    private var remoteBehaviors: [String: (Data) -> Data?] = [:]

    public required init() {
        unsafeUUID = UUID().uuidString
        isNamedService = false
    }

    public required init(_ uuid: String) {
        unsafeUUID = uuid
        isNamedService = true
    }

    public func unsafeIsConnected() -> Bool {
        return nodeSocketFD > 0
    }

    deinit {
        if isNamedService == false {
            pony_remote_destroy_actor(unsafeUUID, &nodeSocketFD)
        }
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
