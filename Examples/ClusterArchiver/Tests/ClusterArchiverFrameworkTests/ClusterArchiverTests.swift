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
        // lzip command on corpus of 9450 files (1 local cores):
        // time sh -c 'find . -type f | xargs -I{} -P 1 lzip {}'  515.42s user 30.89s system 98% cpu 9:12.97 total
        // time sh -c 'find . -type f | xargs -I{} -P 1 lzip -d {}'  47.48s user 15.03s system 91% cpu 1:07.99 total
        
        // lzip command parallelized on corpus of 9450 files (4 local cores)
        // time sh -c 'find . -type f | xargs -I{} -P 4 lzip {}'  543.85s user 33.08s system 393% cpu 2:26.44 total
        // time sh -c 'find . -type f | xargs -I{} -P 4 lzip -d {}'  48.68s user 17.12s system 362% cpu 18.176 total
        
        // lzip command parallelized on corpus of 9450 files (28 local cores)
        // time sh -c 'find . -type f | xargs -I{} -P 28 lzip {}'  472.68s user 40.70s system 2671% cpu 19.217 total
        // time sh -c 'find . -type f | xargs -I{} -P 28 lzip -d {}'  46.53s user 18.67s system 949% cpu 6.867 totalal
        

        // 28 local cores, no remotes
        // compression: 9450 / 0 files in 19.877262949943542s, max concurrent 28
        // decompression: 9450 / 0 files in 6.540912985801697s, max concurrent 28
        
        // 172 remote cores
        // compression: 0 / 9450 files in 9.260679006576538s, max concurrent 172
        // decompression: 0 / 9450 files in 7.3913960456848145s, max concurrent 172
        
        // 28 local cores / 172 remote cores
        // compression: 1607 / 7843 files in 8.442137956619263s, max concurrent 200
        // decompression: 1586 / 7864 files in 6.86386501789093s, max concurrent 200
        
        ClusterArchiver.archive(directory: "/Users/rjbowli/Desktop/TESTARCHIVE",
                                address: "0.0.0.0",
                                port: 9090)
    }
    
    func testLargeArchive2() throws {
        ClusterArchiver.archive(directory: "/Users/rjbowli/Desktop/TESTARCHIVE_LARGE",
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
