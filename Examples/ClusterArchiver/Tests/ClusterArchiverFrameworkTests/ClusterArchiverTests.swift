import XCTest
import class Foundation.Bundle

// swiftlint:disable line_length

import ClusterArchiverFramework

final class ClusterArchiverTests: XCTestCase {

    func testArchive() throws {
        ClusterArchiver.archive(directory: "/Volumes/Development/Development/chimerasw2/flynn/Examples/ClusterArchiver/meta/data",
                                address: "0.0.0.0",
                                port: 9090)
    }
    
    func testLargeArchive() throws {
        // Comparison to lzip command on corpus of 2195 files:
        // rjbowli@beast TESTARCHIVE % time lzip *
        // lzip *  107.66s user 2.14s system 99% cpu 1:49.82 total
        // rjbowli@beast TESTARCHIVE % time lzip -d *
        // lzip -d *  13.27s user 0.90s system 99% cpu 14.200 total

        // compression: 2195 files in 13.726246953010559s, max concurrent 28
        // decompression: 2195 files in 2.111764907836914s, max concurrent 28
        
        ClusterArchiver.archive(directory: "/Users/rjbowli/Desktop/TESTARCHIVE",
                                address: "0.0.0.0",
                                port: 9090)
    }
    
    func testSupport() throws {
        ClusterArchiver.support(address: "0.0.0.0",
                                port: 9090)
    }

    static var allTests = [
        ("testNode", testArchive),
        ("testRoot", testSupport),
    ]
}
