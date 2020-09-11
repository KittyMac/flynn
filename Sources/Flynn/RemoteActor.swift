import Foundation
import Pony

open class RemoteActor {

    public let unsafeUUID: String

    private var slaveID: Int32 = -1

    // MARK: - Functions

    public init() {
        Flynn.startup()
        unsafeUUID = UUID().uuidString
    }

    deinit {
        //print("deinit - RemoteActor")
    }

    public func unsafeSendToRemote(_ actorType: String, _ jsonData: Data, _ sender: Actor?, _ callback: (() -> Void)?) {
        _ = jsonData.withUnsafeBytes {
            pony_remote_actor_send_message_to_slave(unsafeUUID,
                                                    actorType,
                                                    &slaveID,
                                                    $0.baseAddress,
                                                    Int32(jsonData.count))
        }
    }

    public func unsafeSend(actorUUID: String, _ jsonData: Data) {
        _ = jsonData.withUnsafeBytes {
            pony_remote_actor_send_message_to_master(actorUUID, $0.baseAddress, Int32(jsonData.count))
        }
    }
}
