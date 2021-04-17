import Flynn
import Foundation

public enum ClusterArchiver {
    public static func support(address: String,
                               port: Int32) {

        Flynn.Node.connect(address,
                           port,
                           true,
                           remoteActorTypes: [Support.self],
                           namedRemoteActors: [])

        while true {
            sleep(1000)
        }
    }

    public static func archive(directory: String,
                               address: String,
                               port: Int32) {

        Flynn.startup()

        Flynn.Root.listen(address,
                          port,
                          remoteActorTypes: [Support.self],
                          fallbackRemoteActorTypes: [Support.self],
                          namedRemoteActorTypes: [])

        Archiver.init(directory: directory)

        Flynn.shutdown()
    }
}
