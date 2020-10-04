import Foundation
import Pony

public typealias DelayedRemoteBehavior = (Data, @escaping (Data) -> Void) -> Void
public typealias RemoteBehavior = (Data) -> Data?
public typealias RemoteBehaviorReply = (Data) -> Void

public protocol BehaviorRegisterable {
    func unsafeRegisterAllBehaviors()
}

public typealias RemoteActor = ( InternalRemoteActor & BehaviorRegisterable )

open class InternalRemoteActor {

    public let unsafeUUID: String
    
    public let unsafeIsProxy: Bool
    
    private let isNamedService: Bool

    private var nodeSocketFD: Int32 = -1

    private var remoteBehaviors: [String: RemoteBehavior] = [:]
    private var delayedRemoteBehaviors: [String: DelayedRemoteBehavior] = [:]
    
    
    open func safeInit() {
        
    }

    public required init() {
        unsafeUUID = UUID().uuidString
        isNamedService = false
        unsafeIsProxy = true
    }

    public required init(_ uuid: String) {
        unsafeUUID = uuid
        isNamedService = true
        unsafeIsProxy = false
        safeInit()
    }

    public required init(_ uuid: String, _ socketFD: Int32, _ shouldBeProxy: Bool) {
        unsafeUUID = uuid
        nodeSocketFD = socketFD
        isNamedService = true
        unsafeIsProxy = shouldBeProxy
        if !shouldBeProxy {
            safeInit()
        }
    }

    public func unsafeIsConnected() -> Bool {
        return nodeSocketFD >= 0
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
    
    public func safeRegisterDelayedRemoteBehavior(_ name: String, behavior: @escaping DelayedRemoteBehavior) {
        delayedRemoteBehaviors[name] = behavior
    }

    public func unsafeExecuteBehavior(_ name: String, _ payload: Data, _ messageID: Int32, _ replySocketFD: Int32) {
        // regular remote behaviors either return nothing (nil) or
        // return data to be sent back immediately
        if let behavior = remoteBehaviors[name] {
            if let data = behavior(payload) {
                data.withUnsafeBytes {
                    pony_remote_actor_send_message_to_root(replySocketFD,
                                                           messageID,
                                                           $0.baseAddress,
                                                           Int32(data.count))
                }
            }
        }
        
        // delayed remote behaviors are given a closure to call when
        // they are ready to respond to a message
        if let behavior = delayedRemoteBehaviors[name] {
            behavior(payload) {
                $0.withUnsafeBytes {
                    pony_remote_actor_send_message_to_root(replySocketFD,
                                                           messageID,
                                                           $0.baseAddress,
                                                           Int32($0.count))
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
            

            let messageID = pony_remote_actor_send_message_to_node(unsafeUUID,
                                                                   actorType,
                                                                   behaviorType,
                                                                   &nodeSocketFD,
                                                                   $0.baseAddress,
                                                                   Int32(jsonData.count))
            if let sender = sender, let callback = callback {
                RemoteActorManager.shared.beRegisterReply(unsafeUUID, messageID, sender, callback)
            }
        }
    }
}
