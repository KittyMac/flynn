import Foundation
import Pony

open class RemoteActor {

    public let unsafeUUID: String

    private var slaveSocketFD: Int32 = -1

    // MARK: - Functions

    public init() {
        Flynn.startup()
        unsafeUUID = UUID().uuidString
    }

    deinit {
        pony_remote_destroy_actor(unsafeUUID, &slaveSocketFD)
        //print("deinit - RemoteActor")
    }

    public func unsafeSendToRemote(_ actorType: String,
                                   _ behaviorType: String,
                                   _ jsonData: Data,
                                   _ sender: Actor?,
                                   _ callback: (() -> Void)?) {
        _ = jsonData.withUnsafeBytes {
            pony_remote_actor_send_message_to_slave(unsafeUUID,
                                                    actorType,
                                                    behaviorType,
                                                    &slaveSocketFD,
                                                    $0.baseAddress,
                                                    Int32(jsonData.count))
        }
    }

    public func unsafeSendReply(actorUUID: String,
                                _ jsonData: Data) {
        _ = jsonData.withUnsafeBytes {
            pony_remote_actor_send_message_to_master(actorUUID, $0.baseAddress, Int32(jsonData.count))
        }
    }
}
