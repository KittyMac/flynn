import Foundation
import Pony

// MARK: - FLYNN EXTENSION

private func nodeRegisterWithRoot(_ registrationString: UnsafePointer<Int8>?,
                                  _ socketFD: Int32) {
    guard let registrationString = registrationString else { return }

    Flynn.remotes.beRegisterRemoteNodeOnRoot(String(cString: registrationString),
                                                    socketFD)

}

private func nodeCreateActor(_ actorUUIDPtr: UnsafePointer<Int8>?,
                             _ actorTypePtr: UnsafePointer<Int8>?,
                             _ shouldBeProxy: Bool,
                             _ socketFD: Int32) {
    guard let actorUUIDPtr = actorUUIDPtr else { return }
    guard let actorTypePtr = actorTypePtr else { return }

    Flynn.remotes.beCreateActorOnNode(String(cString: actorUUIDPtr),
                                      String(cString: actorTypePtr),
                                      socketFD)

}

private func nodeDestroyActor(_ actorUUIDPtr: UnsafePointer<Int8>?) {
    guard let actorUUIDPtr = actorUUIDPtr else { return }

    Flynn.remotes.beDestroyActor(String(cString: actorUUIDPtr))
}

private func nodeHandleMessage(_ actorUUIDPtr: UnsafePointer<Int8>?,
                               _ behaviorPtr: UnsafePointer<Int8>?,
                               _ payload: AnyPtr,
                               _ payloadSize: Int32,
                               _ messageID: Int32,
                               _ replySocketFD: Int32) {
    guard let actorUUIDPtr = actorUUIDPtr else { return }
    guard let behaviorPtr = behaviorPtr else { return }
    guard let payload = payload else { return }

    Flynn.remotes.beHandleMessage(String(cString: actorUUIDPtr),
                                              String(cString: behaviorPtr),
                                              Data(bytesNoCopy: payload, count: Int(payloadSize), deallocator: .free),
                                              messageID,
                                              replySocketFD)
}

private func nodeRegisterActorsOnRoot(_ replySocketFD: Int32) {
    // We are a node and we've just connected to a root. We need to let the
    // root know the actor types of remote actors we support. We also need to
    // ask the root to create any actors we currently have in existance on our
    // RemoteActorManager (so the root knows that a remote service exists
    // on this remote, for example).
    Flynn.remotes.unsafeRegisterNodeWithRoot(replySocketFD)

}

private func rootHandleMessageReply(_ messageID: Int32,
                                    _ payload: AnyPtr,
                                    _ payloadSize: Int32) {
    if let payload = payload {
        Flynn.remotes.beHandleMessageReply(messageID,
                                                       Data(bytesNoCopy: payload,
                                                            count: Int(payloadSize),
                                                            deallocator: .free))
    } else {
        Flynn.remotes.beHandleMessageReply(messageID, Data())
    }
}

extension Flynn {
    public enum Root {
        public static func listen(_ address: String,
                                  _ port: Int32,
                                  remoteActorTypes: [RemoteActor.Type],
                                  fallbackRemoteActorTypes: [RemoteActor.Type],
                                  namedRemoteActorTypes: [RemoteActor.Type]) {
            Flynn.startup()
                        
            Flynn.remotes.beRegisterActorTypesForRoot(remoteActorTypes,
                                                      fallbackRemoteActorTypes,
                                                      namedRemoteActorTypes,
                                                      Flynn.any) { (_) in
                pony_root(address,
                          port,
                          nodeRegisterWithRoot,
                          nodeCreateActor,
                          rootHandleMessageReply)
            }
        }

        public static func remoteActorByUUID(_ actorUUID: String,
                                             _ sender: Actor,
                                             _ callback: @escaping (RemoteActor?) -> Void) {
            Flynn.remotes.beGetActor(actorUUID, sender, callback)
        }
    }

    public enum Node {
        public static func connect(_ address: String,
                                   _ port: Int32,
                                   _ automaticReconnect: Bool,
                                   remoteActorTypes: [RemoteActor.Type],
                                   namedRemoteActors: [RemoteActor]) {
            Flynn.startup()
            
            Flynn.remotes.beRegisterActorTypesForNode(remoteActorTypes,
                                                      namedRemoteActors,
                                                      Flynn.any) { (_) in
                
                pony_node(address,
                          port,
                          automaticReconnect,
                          nodeCreateActor,
                          nodeDestroyActor,
                          nodeHandleMessage,
                          nodeRegisterActorsOnRoot)
            }
        }
    }
}
