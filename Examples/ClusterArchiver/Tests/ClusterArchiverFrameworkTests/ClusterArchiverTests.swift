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
        // time sh -c 'find . -type f | xargs -I{} -P 28 lzip {}'  475.42s user 39.78s system 2673% cpu 19.268 total
        // time sh -c 'find . -type f | xargs -I{} -P 28 lzip -d {}'  46.49s user 18.56s system 950% cpu 6.846 total
        

        // 28 local cores, no remotes
        // compression: 9450 / 0 files in 31.540642023086548s, max concurrent 28
        // decompression: 9450 / 0 files in 6.716953992843628s, max concurrent 28
        
        // 172 remote cores
        // compression: 9450 files in 33.55566692352295s, max concurrent 172
        // decompression: 9450 files in 21.780818939208984s, max concurrent 172
        
        // 28 local cores / 172 remote cores
        // compression: 5328 / 4122 files in 24.649017095565796s, max concurrent 200
        // decompression: 7188 / 2262 files in 5.691049933433533s, max concurrent 200
        
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
