import Flynn
import Foundation
import LzSwift

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
                          fallbackRemoteActorTypes: remoteActorManifest,
                          namedRemoteActorTypes: [])

        Archiver.init(directory: directory)

        Flynn.shutdown(waitForRemotes: true)
    }

    public static func archive(file: String) {
        // Simulate lzip CLI for apples-to-apples comparison
        do {
            let inputURL = URL(fileURLWithPath: file)
            let data = try Data(contentsOf: inputURL)
            var output = Data()
            var outputURL: URL?

            if data.isLzipped {
                outputURL = inputURL.deletingPathExtension()

                let decompressor = Lzip.Decompress()
                output = try decompressor.decompress(input: data)
                decompressor.finish(output: &output)
            } else {
                outputURL = inputURL.appendingPathExtension("lz")

                let compressor = Lzip.Compress(level: .lvl6)
                output = try compressor.compress(input: data)
                compressor.finish(output: &output)
            }

            if let outputURL = outputURL {
                try output.write(to: outputURL)
                try? FileManager.default.removeItem(at: inputURL)
            }

        } catch {
            print("failed: \(error)")
        }

    }
}
