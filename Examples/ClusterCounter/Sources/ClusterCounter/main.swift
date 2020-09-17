import Foundation
import Flynn
import ArgumentParser

import ClusterCounterFramework

struct ClusterCounterCLI: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Example showing Flynn RemoteActors",
        subcommands: [Root.self, Node.self],
        defaultSubcommand: Root.self)

    struct Root: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Root to which nodes will connect")

        @Argument(help: "IP address to listen on")
        var address: String = "0.0.0.0"

        @Argument(help: "TCP port to listen on")
        var port: Int32 = 9090

        mutating func run() throws {
            ClusterCounter.runAsRoot(address, port)
        }
    }

    struct Node: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Remote nodes on which remote actors will run")

        @Argument(help: "IP address to connect to")
        var address: String = "0.0.0.0"

        @Argument(help: "TCP port to connect to")
        var port: Int32 = 9090

        mutating func run() {
            ClusterCounter.runAsNode(address, port)
        }
    }

}

ClusterCounterCLI.main()
