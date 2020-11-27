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

let kUnregistedSocketFD: Int32 = -1
let kLocalSocketFD: Int32 = -99

internal final class RemoteActorManager: Actor {
    private static var _shared = RemoteActorManager()
    static var shared: RemoteActorManager { return _shared }
    private override init() {
        super.init()
        
        print("*******************************************************")
                
        // To preserve causal messaging, we need to ensure that the behaviors for
        // a specific actor are always run on the same runner in the pool.
        if runnerPool.count == 0 {
            for _ in 0..<Flynn.cores {
                runnerPool.append(RemoteActorRunner())
            }
        }
    }
    
    private var destroyed = false
    func unsafeDestroy() {
        // Called internally by Flynn.shutdown()...
        destroyed = true
    }
    
    func unsafeCheckValidity() {
        // Called internally by Flynn.Root and Flynn.Node
        if destroyed {
            destroyed = false
            RemoteActorManager._shared = RemoteActorManager()
        }
    }

    // MARK: - RemoteActorManager: Node
    
    private var actorTypesBySocket: [Int32: [RemoteActor.Type]] = [:]
    private var actorTypes: [String: RemoteActor.Type] = [:]
    private var actors: [String: RemoteActor] = [:]

    private var runnerPool: [RemoteActorRunner] = []
    
    private var localRunnerMessageId: Int32 = 0
    private var remoteNodeRoundRobinIndex = 0
    
    private func didDisconnectFromSocket(_ socket: Int32) {
        actorTypesBySocket[socket] = []
    }
    
    private func _beGetActor(_ actorUUID: String) -> RemoteActor? {
        return actors[actorUUID]
    }

    private func _beRegisterActorType(_ actorType: RemoteActor.Type) -> Bool {
        actorTypes[String(describing: actorType)] = actorType
        return true
    }
    
    private func _beRegisterActorTypes(_ inActorTypes: [RemoteActor.Type]) -> Bool {
        for actorType in inActorTypes {
            actorTypes[String(describing: actorType)] = actorType
        }
        return true
    }

    private func _beRegisterActor(_ actor: RemoteActor) {
        actor.unsafeRegisterAllBehaviors()
        actors[actor.unsafeUUID] = actor
    }

    internal func unsafeRegisterNodeWithRoot(_ socketFD: Int32) {
        // we have two tasks here:
        // 1. let the root know the remote actors this node supports
        // 2. let the root know the remote actors this node has running as services
        
        var combined = "\(Array(actorTypes.keys).joined(separator: "\n"))\n"
        
        for actor in actors.values {
            let actorTypeWithModule = String(describing: actor)

            // actorType will contain the module name as the first part
            // ie: FlynnTests.Echo
            // For remote actor types, we ignore the module name and just
            // use the rest of the full path
            let actorType = actorTypeWithModule.components(separatedBy: ".").dropFirst().joined(separator: ".")
            
            combined.append(actorType)
            combined.append(",")
            combined.append(actor.unsafeUUID)
            combined.append("\n")
        }
        
        if combined.hasSuffix(",") {
            combined.removeLast()
        }
        
        pony_register_node_to_root(socketFD, combined)
        
    }
    
    private func _beRegisterRemoteNode(_ actorRegistrationString: String,
                                       _ socketFD: Int32) {
        
        var remoteTypes:[RemoteActor.Type] = []
        
        let lines = actorRegistrationString.split(separator: "\n")
        for line in lines {
            let parts = line.split(separator: ",")
            if parts.count == 1 {
                if let actorType = actorTypes[String(parts[0])] {
                    remoteTypes.append(actorType)
                }
            } else if parts.count == 2 {
                _beCreateActor(String(parts[1]),
                               String(parts[0]),
                               true,
                               socketFD)
            }
        }
        
        actorTypesBySocket[socketFD] = remoteTypes
    }

    private func _beCreateActor(_ actorUUID: String,
                                _ actorType: String,
                                _ shouldBeProxy: Bool,
                                _ socketFD: Int32) {
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
        } else {
            fatalError("Unregistered remote actor of type \(actorType)")
        }
    }

    private func _beDestroyActor(_ actorUUID: String) {
        actors.removeValue(forKey: actorUUID)
    }
    
    private func _beSendToRemote(_ actorUUID: String,
                                 _ actorTypeString: String,
                                 _ behaviorType: String,
                                 _ inNodeSocketFD: Int32,
                                 _ jsonData: Data,
                                 _ replySender: Actor?,
                                 _ replyCallback: RemoteBehaviorReply?) -> Int32 {
        
        var nodeSocketFD: Int32 = inNodeSocketFD
        
        let fallbackRunRemoteActorLocally: (() -> Int32) = {
            if nodeSocketFD == kUnregistedSocketFD {
                nodeSocketFD = kLocalSocketFD
                
                self._beCreateActor(actorUUID,
                                    actorTypeString,
                                    false,
                                    nodeSocketFD)
            }
            
            self.localRunnerMessageId += 1
            
            if let replySender = replySender, let replyCallback = replyCallback {
                self._beRegisterReply(self.unsafeUUID, self.localRunnerMessageId, replySender, replyCallback)
            }
            
            RemoteActorManager.shared.beHandleMessage(actorUUID,
                                                      behaviorType,
                                                      jsonData,
                                                      self.localRunnerMessageId,
                                                      kLocalSocketFD)
            
            return nodeSocketFD
        }
        
        if nodeSocketFD == kLocalSocketFD {
            return fallbackRunRemoteActorLocally()
        }
        
        
        if let actorType = actorTypes[actorTypeString] {
            _ = jsonData.withUnsafeBytes {
                
                // if inNodeSocketFD is kUnregistedSocketFD, then we are not attached to a node yet.
                // round robin choose the next node which supports this actor type
                if nodeSocketFD == kUnregistedSocketFD {
                    var allSockets:[Int32] = []
                    for socket in actorTypesBySocket.keys {
                        if let types = actorTypesBySocket[socket] {
                            for type in types {
                                if type == actorType {
                                    allSockets.append(socket)
                                    break
                                }
                            }
                        }
                    }
                    if allSockets.count > 0 {
                        remoteNodeRoundRobinIndex += 1
                        nodeSocketFD = allSockets[remoteNodeRoundRobinIndex % allSockets.count]
                    }
                }
                
                if nodeSocketFD == -1 {
                    nodeSocketFD = fallbackRunRemoteActorLocally()
                } else {
                    let messageID = pony_remote_actor_send_message_to_node(actorUUID,
                                                                           actorTypeString,
                                                                           behaviorType,
                                                                           (inNodeSocketFD < 0),
                                                                           nodeSocketFD,
                                                                           $0.baseAddress,
                                                                           Int32(jsonData.count))
                    if messageID < 0 {
                        // we're no longer connected to this socket
                        didDisconnectFromSocket(nodeSocketFD)
                        nodeSocketFD = -1
                    } else {
                        if let replySender = replySender, let replyCallback = replyCallback {
                            _beRegisterReply(unsafeUUID, messageID, replySender, replyCallback)
                        }
                    }
                }
            }
        } else {
            if nodeSocketFD == -1 {
                nodeSocketFD = fallbackRunRemoteActorLocally()
            }
        }
        
        return nodeSocketFD
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
    public func beRegisterActorType(_ actorType: RemoteActor.Type,
                                    _ sender: Actor,
                                    _ callback: @escaping ((Bool) -> Void)) -> Self {
        unsafeSend() {
            let result = self._beRegisterActorType(actorType)
            sender.unsafeSend { callback(result) }
        }
        return self
    }
    @discardableResult
    public func beRegisterActorTypes(_ inActorTypes: [RemoteActor.Type],
                                     _ sender: Actor,
                                     _ callback: @escaping ((Bool) -> Void)) -> Self {
        unsafeSend() {
            let result = self._beRegisterActorTypes(inActorTypes)
            sender.unsafeSend { callback(result) }
        }
        return self
    }
    @discardableResult
    public func beRegisterActor(_ actor: RemoteActor) -> Self {
        unsafeSend { self._beRegisterActor(actor) }
        return self
    }
    @discardableResult
    public func beRegisterRemoteNode(_ actorRegistrationString: String,
                                     _ socketFD: Int32) -> Self {
        unsafeSend { self._beRegisterRemoteNode(actorRegistrationString, socketFD) }
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
    public func beSendToRemote(_ actorUUID: String,
                               _ actorTypeString: String,
                               _ behaviorType: String,
                               _ inNodeSocketFD: Int32,
                               _ jsonData: Data,
                               _ replySender: Actor?,
                               _ replyCallback: RemoteBehaviorReply?,
                               _ sender: Actor,
                               _ callback: @escaping ((Int32) -> Void)) -> Self {
        unsafeSend() {
            let result = self._beSendToRemote(actorUUID, actorTypeString, behaviorType, inNodeSocketFD, jsonData, replySender, replyCallback)
            sender.unsafeSend { callback(result) }
        }
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
