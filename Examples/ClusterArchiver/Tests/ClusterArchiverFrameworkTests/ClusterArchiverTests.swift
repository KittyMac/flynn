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
        // lzip command on corpus of 5065 files:
        // find . -type f -exec lzip {} \;  248.63s user 20.61s system 98% cpu 4:32.57 total
        // find . -type f -exec lzip -d {} \;  28.71s user 11.07s system 94% cpu 41.911 total

        // 28 local cores, no remotes
        // compression: 5065 files in 5065 files in 25.013348937034607s, max concurrent 28
        // decompression: 5065 files in 4.0041139125823975s, max concurrent 28
        
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
