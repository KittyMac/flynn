import Flynn
import Foundation

private let remoteActorManifest: [RemoteActor.Type] = [RemoteCompressor.self, RemoteDecompressor.self]

public enum ClusterArchiver {

    public static func support(address: String,
                               port: Int32) {

        Flynn.Node.connect(address,
                           port,
                           true,
                           remoteActorTypes: remoteActorManifest,
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
                          remoteActorTypes: remoteActorManifest,
                          fallbackRemoteActorTypes: [],
                          namedRemoteActorTypes: [])

        Archiver.init(directory: directory)

        Flynn.shutdown(waitForRemotes: true)
    }
}
