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
        // export CLUSTERARCHIVER=/Volumes/Development/Development/chimerasw2/flynn/Examples/ClusterArchiver/.build/x86_64-apple-macosx/release/ClusterArchiver
        
        // Provided for Apples -> Oranges comparison
        // lzip command on corpus of 9449 files (1 local cores):
        // compression: time sh -c 'find . -type f | xargs -I{} -P 1 lzip {}'  515.42s user 30.89s system 98% cpu 9:12.97 total
        // decompression: time sh -c 'find . -type f | xargs -I{} -P 1 lzip -d {}'  47.48s user 15.03s system 91% cpu 1:07.99 total
        
        // lzip command parallelized on corpus of 9449 files (4 local cores)
        // compression: time sh -c 'find . -type f | xargs -I{} -P 4 lzip {}'  543.85s user 33.08s system 393% cpu 2:26.44 total
        // decompression: time sh -c 'find . -type f | xargs -I{} -P 4 lzip -d {}'  48.68s user 17.12s system 362% cpu 18.176 total
        
        // lzip command parallelized on corpus of 9449 files (28 local cores)
        // compression: time sh -c 'find . -type f | xargs -I{} -P 28 lzip {}'  467.60s user 38.38s system 2477% cpu 20.421 total
        // decompression: time sh -c 'find . -type f | xargs -I{} -P 28 lzip -d {}'  48.14s user 19.30s system 944% cpu 7.142 total
        
        // Provided for Apples -> Apples comparison
        // ClusterArchiver archive one command on corpus of 9449 files (1 local cores):
        // compression: time sh -c 'find . -type f | xargs -I{} -P 1 $CLUSTERARCHIVER {}'  455.19s user 107.47s system 96% cpu 9:43.05 total
        // decompression: time sh -c 'find . -type f | xargs -I{} -P 1 $CLUSTERARCHIVER {}'  94.41s user 52.66s system 90% cpu 2:43.11 total
        
        // ClusterArchiver archive one command parallelized on corpus of 9449 files (4 local cores)
        // compression: time sh -c 'find . -type f | xargs -I{} -P 4 $CLUSTERARCHIVER {}'  476.51s user 118.80s system 383% cpu 2:35.26 total
        // decompression: time sh -c 'find . -type f | xargs -I{} -P 4 $CLUSTERARCHIVER {}'  90.50s user 51.35s system 360% cpu 39.400 total
        
        // ClusterArchiver archive one command parallelized on corpus of 9449 files (28 local cores)
        // compression: time sh -c 'find . -type f | xargs -I{} -P 28 $CLUSTERARCHIVER {}'  583.89s user 342.29s system 2489% cpu 37.200 total
        // decompression: time sh -c 'find . -type f | xargs -I{} -P 28 $CLUSTERARCHIVER {}'  467.60s user 38.38s system 2477% cpu 20.421 total
        

        // 28 local cores, no remotes
        // compression: 9449 / 0 files in 35.72971296310425s, max concurrent 28
        // decompression: 9449 / 0 files in 6.199898958206177s, max concurrent 28
        
        // 172 remote cores
        // compression: 0 / 9449 files in 28.26699197292328s, max concurrent 172
        // decompression: 0 / 9449 files in 15.174230098724365s, max concurrent 172
        
        // 28 local cores / 172 remote cores
        // compression: 4024 / 5425 files in 15.612917065620422s, max concurrent 200
        // decompression: 5080 / 4369 files in 8.551880955696106s, max concurrent 200
        
        
        // Single large file (1.63 GB // 23.1 GB)
        // time lzip -d /Users/rjbowli/Desktop/TESTARCHIVE_LARGE/ProdGmailErrorLog20210315t0000-To-20210316t0000.csv.lz
        // lzip -d   254.11s user 10.42s system 38% cpu 11:18.83 total
        // ./minilzip -d   179.59s user 13.59s system 60% cpu 5:21.19 total
        
        ClusterArchiver.archive(directory: "/Volumes/Optane/ClusterArchiver/TESTARCHIVE",
                                address: "0.0.0.0",
                                port: 9090)
    }
    
    func testLargeArchive2() throws {
        ClusterArchiver.archive(directory: "/Volumes/Optane/ClusterArchiver/TESTARCHIVE_LARGE",
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
