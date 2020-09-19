import Foundation
import Pony

// MARK: - FLYNN EXTENSION

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
    public enum Root {
        public static func listen(_ address: String, _ port: Int32) {
            pony_root(address,
                        port,
                        rootHandleMessageReply)
        }
    }

    public enum Node {
        public static func connect(_ address: String,
                                   _ port: Int32) {
            Flynn.startup()

            pony_node(address,
                      port,
                      nodeCreateActor,
                      nodeDestroyActor,
                      nodeHandleMessage)
        }

        public static func registerActorTypes(_ actorTypes: [RemoteActor.Type]) {
            for actorType in actorTypes {
                RemoteActorManager.shared.beRegisterActorType(actorType)
            }
        }

        public static func registerActors(_ actors: [RemoteActor]) {
            for actor in actors {
                RemoteActorManager.shared.beRegisterActor(actor)
            }
        }
    }
}
