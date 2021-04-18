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
        // lzip command on corpus of 9450 files (sequential):
        // time find . -type f -exec lzip {} \;  370.36s user 30.42s system 97% cpu 6:49.87 total
        // time find . -type f -exec lzip -d {} \;  47.55s user 19.89s system 93% cpu 1:11.85 total
        
        // lzip command parallelized on corpus of 9450 files
        // time sh -c 'find . -type f | xargs -I{} -P 28 lzip {}'  475.42s user 39.78s system 2673% cpu 19.268 total
        // time sh -c 'find . -type f | xargs -I{} -P 28 lzip -d {}'  46.49s user 18.56s system 950% cpu 6.846 total
        

        // 28 local cores, no remotes
        // compression: 5065 files in 5065 files in 25.013348937034607s, max concurrent 28
        // decompression: 5065 files in 4.0041139125823975s, max concurrent 28
        
        // 172 remote cores
        // compression: 9450 files in 31.72487998008728s, max concurrent 172
        // decompression: 9450 files in 19.5029399394989s, max concurrent 172
        
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
