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
    override init() {
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
    
    private var numRemoteCoresBySocket: [Int32: Int32] = [:]
    private var actorTypesBySocket: [Int32: [RemoteActor.Type]] = [:]
    
    private var fallbackActorTypes: [String: RemoteActor.Type] = [:]
    private var namedActorTypes: [String: RemoteActor.Type] = [:]
    
    private var nodeActorTypes: [String: RemoteActor.Type] = [:]
    private var rootActorTypes: [String: RemoteActor.Type] = [:]
    
    private var nodeActors: [String: RemoteActor] = [:]
    private var rootActors: [String: RemoteActor] = [:]

    private var runnerPool: [RemoteActorRunner] = []
    
    private var remoteNodeRoundRobinIndex = 0
    
    public func unsafeReset() {
        numRemoteCoresBySocket.removeAll()
        actorTypesBySocket.removeAll()
        
        fallbackActorTypes.removeAll()
        namedActorTypes.removeAll()
        
        nodeActorTypes.removeAll()
        rootActorTypes.removeAll()
        
        nodeActors.removeAll()
        rootActors.removeAll()
    }
    
    private func didDisconnectFromSocket(_ socket: Int32) {
        actorTypesBySocket[socket] = []
    }
    
    private func _beGetActor(_ actorUUID: String) -> RemoteActor? {
        return rootActors[actorUUID]
    }
    
    private func _beRegisterActorTypesForRoot(_ inRootActorTypes: [RemoteActor.Type],
                                              _ inFallbackActorTypes: [RemoteActor.Type],
                                              _ inNamedActorTypes: [RemoteActor.Type]) -> Bool {
        for actorType in inRootActorTypes {
            rootActorTypes[String(describing: actorType)] = actorType
        }
        for actorType in inFallbackActorTypes {
            fallbackActorTypes[String(describing: actorType)] = actorType
        }
        for actorType in inNamedActorTypes {
            namedActorTypes[String(describing: actorType)] = actorType
        }
        return true
    }
    
    private func _beRegisterActorTypesForNode(_ inActorTypes: [RemoteActor.Type],
                                              _ namedActors: [RemoteActor]) -> Bool {
        for actorType in inActorTypes {
            nodeActorTypes[String(describing: actorType)] = actorType
        }
        for actor in namedActors {
            actor.unsafeRegisterAllBehaviors()
            nodeActors[actor.unsafeUUID] = actor
            
            namedActorTypes[String(describing: type(of: actor))] = type(of: actor)
        }
        return true
    }

    internal func unsafeRegisterNodeWithRoot(_ socketFD: Int32) {
        // we have two tasks here:
        // 1. let the root know the remote actors this node supports
        // 2. let the root know the remote actors this node has running as services
        
        var combined = "\(Array(nodeActorTypes.keys).joined(separator: "\n"))\n"
        
        for actor in nodeActors.values {
            let actorTypeWithModule = String(describing: actor)

            // actorType will contain the module name as the first part
            // ie: FlynnTests.Echo
            // For remote actor types, we ignore the module name and just
            // use the rest of the full path
            let actorType = actorTypeWithModule.components(separatedBy: ".").dropFirst().joined(separator: ".")
            
            if namedActorTypes[actorType] != nil {
                combined.append(actorType)
                combined.append(",")
                combined.append(actor.unsafeUUID)
                combined.append("\n")
            }
        }
        
        if combined.hasSuffix(",") {
            combined.removeLast()
        }
        
        pony_register_node_to_root(socketFD, combined)
        
    }
    
    private func _beRegisterRemoteNodeOnRoot(_ actorRegistrationString: String,
                                             _ socketFD: Int32) {
        
        var remoteTypes:[RemoteActor.Type] = []
        
        let lines = actorRegistrationString.split(separator: "\n")
        for line in lines {
            let parts = line.split(separator: ",")
            if parts.count == 1 {
                if let actorType = rootActorTypes[String(parts[0])] {
                    remoteTypes.append(actorType)
                }
            } else if parts.count == 2 {
                _beCreateActorOnRoot(String(parts[1]),
                                     String(parts[0]),
                                     socketFD)
            }
        }
        
        actorTypesBySocket[socketFD] = remoteTypes
    }

    private func _beCreateActorOnNode(_ actorUUID: String,
                                      _ actorType: String,
                                      _ socketFD: Int32) {
        guard nodeActors[actorUUID] == nil else { return }
        
        if let actorType = nodeActorTypes[actorType] {
            let actor = actorType.init(actorUUID, socketFD, false)
            actor.unsafeRegisterAllBehaviors()
            nodeActors[actorUUID] = actor
        } else {
            fatalError("Unregistered remote actor of type \(actorType); properly include all valid types in Flynn.Node.connect()")
        }
    }
    
    private func _beCreateActorOnRoot(_ actorUUID: String,
                                      _ actorType: String,
                                      _ socketFD: Int32) {
        if let actorType = namedActorTypes[actorType] {
            let actor = actorType.init(actorUUID, socketFD, true)
            actor.unsafeRegisterAllBehaviors()
            rootActors[actorUUID] = actor
        } else if let actorType = rootActorTypes[actorType] {
            let actor = actorType.init(actorUUID, socketFD, false)
            actor.unsafeRegisterAllBehaviors()
            rootActors[actorUUID] = actor
        } else {
            fatalError("Unregistered remote actor of type \(actorType); properly include all valid types in Flynn.Root.listen()")
        }
    }

    private func _beDestroyActor(_ actorUUID: String) {
        rootActors.removeValue(forKey: actorUUID)
        nodeActors.removeValue(forKey: actorUUID)
    }
    
    private func _beRootTellNodeToDestroyActor(_ actorUUID: String,
                                               _ nodeSocketFD: Int32) {
        pony_root_destroy_actor_to_node(actorUUID, nodeSocketFD)
    }
    
    private func _beNodeTellRootActorWasDestroyed(_ actorUUID: String,
                                                  _ nodeSocketFD: Int32) {
        pony_node_destroy_actor_to_root(nodeSocketFD)
    }
    
    private func _beSendToRemote(_ internalRemoteActor: InternalRemoteActor,
                                 _ actorUUID: String,
                                 _ actorTypeString: String,
                                 _ behaviorType: String,
                                 _ payload: Data,
                                 _ replySender: Actor?,
                                 _ replyCallback: RemoteBehaviorReply?) {
        let fallbackRunRemoteActorLocally: (() -> Void) = {
            guard let _ = self.fallbackActorTypes[actorTypeString] else {
                fatalError("Unregistered remote actor of type \(actorTypeString); properly include all valid types in Flynn.Root.listen()")
            }
            
            if internalRemoteActor.nodeSocketFD == kUnregistedSocketFD {
                internalRemoteActor.nodeSocketFD = kLocalSocketFD
                
                self._beCreateActorOnRoot(actorUUID,
                                          actorTypeString,
                                          internalRemoteActor.nodeSocketFD)
            }
            
            let messageId = pony_next_messageId()
            
            if let replySender = replySender, let replyCallback = replyCallback {
                self._beRegisterReply(messageId, replySender, replyCallback)
            }
            
            Flynn.remotes.beHandleMessage(actorUUID,
                                          behaviorType,
                                          payload,
                                          messageId,
                                          kLocalSocketFD)
        }
        
        if internalRemoteActor.nodeSocketFD == kLocalSocketFD {
            return fallbackRunRemoteActorLocally()
        }
        
        let finishSendingToRemoteActor: (() -> Void) = {
            _ = payload.withUnsafeBytes {
                let messageID = pony_root_send_actor_message_to_node(actorUUID,
                                                                     actorTypeString,
                                                                     behaviorType,
                                                                     (internalRemoteActor.nodeSocketFD != internalRemoteActor.createdNodeSocketFD),
                                                                     internalRemoteActor.nodeSocketFD,
                                                                     $0.baseAddress,
                                                                     Int32(payload.count))
                if messageID < 0 {
                    // we're no longer connected to this socket
                    self.didDisconnectFromSocket(internalRemoteActor.nodeSocketFD)
                    internalRemoteActor.nodeSocketFD = kUnregistedSocketFD
                    internalRemoteActor.createdNodeSocketFD = internalRemoteActor.nodeSocketFD
                } else {
                    internalRemoteActor.createdNodeSocketFD = internalRemoteActor.nodeSocketFD
                    if let replySender = replySender, let replyCallback = replyCallback {
                        self._beRegisterReply(messageID, replySender, replyCallback)
                    }
                }
            }
        }

        
        if let actorType = rootActorTypes[actorTypeString] {

            // if inNodeSocketFD is kUnregistedSocketFD, then we are not attached to a node yet.
            // round robin choose the next node which supports this actor type
            if internalRemoteActor.nodeSocketFD == kUnregistedSocketFD {
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
                    
                    // sanity default: choose next remote node
                    internalRemoteActor.nodeSocketFD = allSockets[remoteNodeRoundRobinIndex % allSockets.count]

                    // ideal: choose next node based on their core counts (support hetergeneous clusters)
                    //remoteNodeRoundRobinIndex = remoteNodeRoundRobinIndex % Int(pony_remote_core_count())
                    //
                    //var idx: Int32 = 0
                    //for socket in allSockets {
                    //    if idx >= remoteNodeRoundRobinIndex {
                    //        internalRemoteActor.nodeSocketFD = socket
                    //        break
                    //    }
                    //    var numCores = numRemoteCoresBySocket[socket] ?? 0
                    //    if numCores == 0 {
                    //        numCores = pony_remote_core_count_by_socket(socket)
                    //        numRemoteCoresBySocket[socket] = numCores
                    //    }
                    //    idx += numCores
                    //}
                }
            }
            
            if internalRemoteActor.nodeSocketFD == kUnregistedSocketFD {
                fallbackRunRemoteActorLocally()
            } else {
                finishSendingToRemoteActor()
                
                // we tried to send to a disconnected node; try again to
                // either get an active node or a local fallback.
                if internalRemoteActor.nodeSocketFD == kUnregistedSocketFD {
                    return _beSendToRemote(internalRemoteActor,
                                           actorUUID,
                                           actorTypeString,
                                           behaviorType,
                                           payload,
                                           replySender,
                                           replyCallback)
                }
            }
        } else if let _ = namedActorTypes[actorTypeString] {
            if internalRemoteActor.nodeSocketFD != kUnregistedSocketFD {
                finishSendingToRemoteActor()
            } else {
                rootActors[internalRemoteActor.unsafeUUID] = nil
                print("attempting to send behavior to disconnected named remote actor \(actorTypeString)")
            }
        } else {
            if internalRemoteActor.nodeSocketFD == kUnregistedSocketFD {
                fallbackRunRemoteActorLocally()
            }
        }
    }

    private func _beHandleMessage(_ actorUUID: String,
                                  _ behavior: String,
                                  _ data: Data,
                                  _ messageID: Int32,
                                  _ replySocketFD: Int32) {
        if let actor = nodeActors[actorUUID] {
            unsafeGetRunnerForActor(actorUUID).beHandleMessage(actor, behavior, data, messageID, replySocketFD)
        } else if let actor = rootActors[actorUUID] {
            unsafeGetRunnerForActor(actorUUID).beHandleMessage(actor, behavior, data, messageID, replySocketFD)
        }
    }
    
    internal func unsafeGetRunnerForActor(_ actorUUID: String) -> RemoteActorRunner {
        // Ok, this has pros and cons
        // pro: its quick, easy, and guarantees causal messaging
        // con: we won't get amazing distribution across all cores
        let runnerIdx = abs(actorUUID.hashValue) % runnerPool.count
        return runnerPool[runnerIdx]
    }

    // MARK: - RemoteActorManager: Root

    private var waitingReplies: [Int32: MessageReply] = [:]

    private func _beRegisterReply(_ messageID: Int32,
                                  _ actor: Actor,
                                  _ block: @escaping RemoteBehaviorReply) {
        waitingReplies[messageID] = MessageReply(actor, block)
    }

    private func _beHandleMessageReply(_ messageID: Int32,
                                       _ data: Data) {
        if let message = waitingReplies.removeValue(forKey: messageID) {
            message.run(data)
        } else {
            fatalError("Remote message received for message id \(messageID) which does not exist")
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
    public func beRegisterActorTypesForRoot(_ inRootActorTypes: [RemoteActor.Type],
                                            _ inFallbackActorTypes: [RemoteActor.Type],
                                            _ inNamedActorTypes: [RemoteActor.Type],
                                            _ sender: Actor,
                                            _ callback: @escaping ((Bool) -> Void)) -> Self {
        unsafeSend {
            let result = self._beRegisterActorTypesForRoot(inRootActorTypes, inFallbackActorTypes, inNamedActorTypes)
            sender.unsafeSend { callback(result) }
        }
        return self
    }
    @discardableResult
    public func beRegisterActorTypesForNode(_ inActorTypes: [RemoteActor.Type],
                                            _ namedActors: [RemoteActor],
                                            _ sender: Actor,
                                            _ callback: @escaping ((Bool) -> Void)) -> Self {
        unsafeSend {
            let result = self._beRegisterActorTypesForNode(inActorTypes, namedActors)
            sender.unsafeSend { callback(result) }
        }
        return self
    }
    @discardableResult
    public func beRegisterRemoteNodeOnRoot(_ actorRegistrationString: String,
                                           _ socketFD: Int32) -> Self {
        unsafeSend { self._beRegisterRemoteNodeOnRoot(actorRegistrationString, socketFD) }
        return self
    }
    @discardableResult
    public func beCreateActorOnNode(_ actorUUID: String,
                                    _ actorType: String,
                                    _ socketFD: Int32) -> Self {
        unsafeSend { self._beCreateActorOnNode(actorUUID, actorType, socketFD) }
        return self
    }
    @discardableResult
    public func beCreateActorOnRoot(_ actorUUID: String,
                                    _ actorType: String,
                                    _ socketFD: Int32) -> Self {
        unsafeSend { self._beCreateActorOnRoot(actorUUID, actorType, socketFD) }
        return self
    }
    @discardableResult
    public func beDestroyActor(_ actorUUID: String) -> Self {
        unsafeSend { self._beDestroyActor(actorUUID) }
        return self
    }
    @discardableResult
    public func beRootTellNodeToDestroyActor(_ actorUUID: String,
                                             _ nodeSocketFD: Int32) -> Self {
        unsafeSend { self._beRootTellNodeToDestroyActor(actorUUID, nodeSocketFD) }
        return self
    }
    @discardableResult
    public func beNodeTellRootActorWasDestroyed(_ actorUUID: String,
                                                _ nodeSocketFD: Int32) -> Self {
        unsafeSend { self._beNodeTellRootActorWasDestroyed(actorUUID, nodeSocketFD) }
        return self
    }
    @discardableResult
    public func beSendToRemote(_ internalRemoteActor: InternalRemoteActor,
                               _ actorUUID: String,
                               _ actorTypeString: String,
                               _ behaviorType: String,
                               _ payload: Data,
                               _ replySender: Actor?,
                               _ replyCallback: RemoteBehaviorReply?) -> Self {
        unsafeSend { self._beSendToRemote(internalRemoteActor, actorUUID, actorTypeString, behaviorType, payload, replySender, replyCallback) }
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
    public func beRegisterReply(_ messageID: Int32,
                                _ actor: Actor,
                                _ block: @escaping RemoteBehaviorReply) -> Self {
        unsafeSend { self._beRegisterReply(messageID, actor, block) }
        return self
    }
    @discardableResult
    public func beHandleMessageReply(_ messageID: Int32,
                                     _ data: Data) -> Self {
        unsafeSend { self._beHandleMessageReply(messageID, data) }
        return self
    }

}
