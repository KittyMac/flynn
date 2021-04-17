import Foundation
import Flynn
import ArgumentParser

import ClusterArchiverFramework

struct ClusterArchiverCLI: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Distributed lzip compression and decompression",
        subcommands: [Archive.self, Support.self],
        defaultSubcommand: Archive.self)

    struct Archive: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Archive files using lzip")

        @Argument(help: "IP address to listen on")
        var address: String = "0.0.0.0"

        @Argument(help: "TCP port to listen on")
        var port: Int32 = 9090

        @Argument(help: "Path to directory of files to archive")
        var directory: String

        mutating func run() throws {
            ClusterArchiver.archive(directory: directory,
                                    address: address,
                                    port: port)
        }
    }

    struct Support: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Support nodes to increase archival bandwidth")

        @Argument(help: "IP address to connect to")
        var address: String = "0.0.0.0"

        @Argument(help: "TCP port to connect to")
        var port: Int32 = 9090

        mutating func run() {
            ClusterArchiver.support(address: address,
                                    port: port)
        }
    }

}

ClusterArchiverCLI.main()
