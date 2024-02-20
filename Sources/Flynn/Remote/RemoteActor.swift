import Foundation
import Pony

public typealias DelayedRemoteBehavior = (Data, @escaping (Data) -> Void) -> Void
public typealias RemoteBehavior = (Data) -> Data?
public typealias RemoteBehaviorReply = (Data) -> Void
public typealias RemoteBehaviorError = () -> Void

public protocol BehaviorRegisterable {
    func unsafeRegisterAllBehaviors()
}

public typealias RemoteActor = ( InternalRemoteActor & BehaviorRegisterable )

fileprivate var unsafeGlobalRunnerIdx = 0

open class InternalRemoteActor: Equatable, Hashable {
    
    public static func == (lhs: InternalRemoteActor, rhs: InternalRemoteActor) -> Bool {
        return lhs.unsafeUUID == rhs.unsafeUUID
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(unsafeUUID)
    }

    public let unsafeRunnerIdx: Int
    public let unsafeUUID: String
    
    public let unsafeIsProxy: Bool
    
    public let safeActor: Actor
    
    private let isNamedService: Bool

    var nodeSocketFD: Int32 = kUnregistedSocketFD
    var createdNodeSocketFD: Int32 = kUnregistedSocketFD

    private var remoteBehaviors: [String: RemoteBehavior] = [:]
    private var delayedRemoteBehaviors: [String: DelayedRemoteBehavior] = [:]
    
    
    open func safeInit() {
        
    }

    public required init() {
        unsafeGlobalRunnerIdx = (unsafeGlobalRunnerIdx + 1) % 4096
        self.unsafeRunnerIdx = unsafeGlobalRunnerIdx
        
        unsafeUUID = UUID().uuidString
        isNamedService = false
        unsafeIsProxy = true
        safeActor = Flynn.any
    }

    public required init(_ uuid: String) {
        unsafeGlobalRunnerIdx = (unsafeGlobalRunnerIdx + 1) % 4096
        self.unsafeRunnerIdx = unsafeGlobalRunnerIdx
        
        unsafeUUID = uuid
        isNamedService = true
        unsafeIsProxy = false
        safeActor = Flynn.remotes.unsafeGetRunnerForActor(unsafeUUID)
        safeInit()
    }

    public required init(_ uuid: String, _ socketFD: Int32, _ shouldBeProxy: Bool) {
        unsafeGlobalRunnerIdx = (unsafeGlobalRunnerIdx + 1) % 4096
        self.unsafeRunnerIdx = unsafeGlobalRunnerIdx
        
        unsafeUUID = uuid
        nodeSocketFD = socketFD
        isNamedService = true
        unsafeIsProxy = shouldBeProxy
        if !shouldBeProxy {
            safeActor = Flynn.remotes.unsafeGetRunnerForActor(unsafeUUID)
            safeInit()
        } else {
            safeActor = Flynn.any
        }
    }

    public func unsafeIsConnected() -> Bool {
        return nodeSocketFD >= 0 || nodeSocketFD == kLocalSocketFD
    }

    deinit {
        if isNamedService == false && nodeSocketFD != kLocalSocketFD && unsafeIsProxy == true {
            Flynn.remotes.beRootTellNodeToDestroyActor(unsafeUUID, nodeSocketFD)
        }
        
        if isNamedService == true && nodeSocketFD != kLocalSocketFD && unsafeIsProxy == false {
            Flynn.remotes.beNodeTellRootActorWasDestroyed(unsafeUUID, nodeSocketFD)
        }

        //print("deinit - RemoteActor [\(nodeSocketFD)]")
    }

    public func safeRegisterRemoteBehavior(_ name: String, behavior: @escaping RemoteBehavior) {
        remoteBehaviors[name] = behavior
    }
    
    public func safeRegisterDelayedRemoteBehavior(_ name: String, behavior: @escaping DelayedRemoteBehavior) {
        delayedRemoteBehaviors[name] = behavior
    }

    // Note: this is run on a Node from RemoteActorRunner only
    public func unsafeExecuteBehavior(_ name: String, _ payload: Data, _ messageID: Int32, _ replySocketFD: Int32) {
        // regular remote behaviors either return nothing (nil) or
        // return data to be sent back immediately
        if let behavior = remoteBehaviors[name] {
            if let data = behavior(payload) {
                if replySocketFD == kLocalSocketFD {
                    Flynn.remotes.beHandleMessageReply(messageID,
                                                                   data)
                } else {
                    data.withUnsafeBytes {
                        pony_node_send_actor_message_to_root(replySocketFD,
                                                             messageID,
                                                             $0.baseAddress,
                                                             Int32(data.count))
                    }
                }
            }
        }
        
        // delayed remote behaviors are given a closure to call when
        // they are ready to respond to a message
        if let behavior = delayedRemoteBehaviors[name] {
            behavior(payload) {
                if replySocketFD == kLocalSocketFD {
                    Flynn.remotes.beHandleMessageReply(messageID, $0)
                } else {
                    $0.withUnsafeBytes {
                        pony_node_send_actor_message_to_root(replySocketFD,
                                                             messageID,
                                                             $0.baseAddress,
                                                             Int32($0.count))
                    }
                }
            }
        }
    }

    public func unsafeSendToRemote(_ actorType: String,
                                   _ behaviorType: String,
                                   _ payload: Data,
                                   _ sender: Actor?,
                                   _ error: RemoteBehaviorError?,
                                   _ callback: RemoteBehaviorReply?) {
        Flynn.remotes.beSendToRemote(self,
                                     unsafeUUID,
                                     actorType,
                                     behaviorType,
                                     payload,
                                     sender,
                                     callback,
                                     error)
    }
}
