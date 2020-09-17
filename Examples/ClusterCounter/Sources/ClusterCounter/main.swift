import Foundation
import Flynn
import ArgumentParser

import ClusterCounterFramework

struct ClusterCounterCLI: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Example showing Flynn RemoteActors",
        subcommands: [Master.self, Slave.self],
        defaultSubcommand: Master.self)

    struct Master: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Master node to which slaves will connect")

        @Argument(help: "IP address to listen on")
        var address: String = "0.0.0.0"

        @Argument(help: "TCP port to listen on")
        var port: Int32 = 9090

        mutating func run() throws {
            ClusterCounter.runAsMaster(address, port)
        }
    }

    struct Slave: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Salve nodes on which RemoteActors will run")

        @Argument(help: "IP address to connect to")
        var address: String = "0.0.0.0"

        @Argument(help: "TCP port to connect to")
        var port: Int32 = 9090

        mutating func run() {
            ClusterCounter.runAsSlave(address, port)
        }
    }

}

ClusterCounterCLI.main()
