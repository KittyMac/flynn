import Foundation
import Pony

// MARK: - FLYNN EXTENSION

private func nodeCreateActor(_ actorUUIDPtr: UnsafePointer<Int8>?,
                             _ actorTypePtr: UnsafePointer<Int8>?,
                             _ shouldBeProxy: Bool,
                             _ socketFD: Int32) {
    guard let actorUUIDPtr = actorUUIDPtr else { return }
    guard let actorTypePtr = actorTypePtr else { return }

    RemoteActorManager.shared.beCreateActor(String(cString: actorUUIDPtr),
                                            String(cString: actorTypePtr),
                                            shouldBeProxy,
                                            socketFD)

}

private func nodeDestroyActor(_ actorUUIDPtr: UnsafePointer<Int8>?) {
    guard let actorUUIDPtr = actorUUIDPtr else { return }

    RemoteActorManager.shared.beDestroyActor(String(cString: actorUUIDPtr))
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

    RemoteActorManager.shared.beHandleMessage(String(cString: actorUUIDPtr),
                                              String(cString: behaviorPtr),
                                              Data(bytesNoCopy: payload, count: Int(payloadSize), deallocator: .free),
                                              messageID,
                                              replySocketFD)
}

private func nodeRegisterActorsOnRoot(_ replySocketFD: Int32) {
    // We are a node and we've just connected to a root. We need to ask the
    // root to create any actors we currently have in existance on our
    // RemoteActorManager (so the root knows that a remote service exists
    // on this remote, for example).
    RemoteActorManager.shared.unsafeRegisterActorsOnRoot(replySocketFD)

}

private func rootHandleMessageReply(_ messageID: Int32,
                                    _ payload: AnyPtr,
                                    _ payloadSize: Int32) {
    if let payload = payload {
        RemoteActorManager.shared.beHandleMessageReply(messageID,
                                                       Data(bytesNoCopy: payload,
                                                            count: Int(payloadSize),
                                                            deallocator: .free))
    } else {
        RemoteActorManager.shared.beHandleMessageReply(messageID, Data())
    }
}

extension Flynn {
    public enum Root {
        public static func listen(_ address: String,
                                  _ port: Int32,
                                  _ actorTypes: [RemoteActor.Type]) {
            pony_root(address,
                      port,
                      nodeCreateActor,
                      rootHandleMessageReply)

            for actorType in actorTypes {
                RemoteActorManager.shared.beRegisterActorType(actorType)
            }
        }

        public static func remoteActorByUUID(_ actorUUID: String,
                                             _ sender: Actor,
                                             _ callback: @escaping (RemoteActor?) -> Void) {
            RemoteActorManager.shared.beGetActor(actorUUID, sender, callback)
        }
    }

    public enum Node {
        public static func connect(_ address: String,
                                   _ port: Int32,
                                   _ actorTypes: [RemoteActor.Type],
                                   _ automaticReconnect: Bool = true) {
            Flynn.startup()

            pony_node(address,
                      port,
                      automaticReconnect,
                      nodeCreateActor,
                      nodeDestroyActor,
                      nodeHandleMessage,
                      nodeRegisterActorsOnRoot)

            for actorType in actorTypes {
                RemoteActorManager.shared.beRegisterActorType(actorType)
            }
        }

        public static func registerActorsWithRoot(_ actors: [RemoteActor]) {
            for actor in actors {
                RemoteActorManager.shared.beRegisterActor(actor)
            }
        }
    }
}
