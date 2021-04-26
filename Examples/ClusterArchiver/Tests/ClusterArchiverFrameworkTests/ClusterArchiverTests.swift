import XCTest
import class Foundation.Bundle

// swiftlint:disable line_length

import ClusterArchiverFramework

final class ClusterArchiverTests: XCTestCase {
    
    func testSingleArchive() throws {
        ClusterArchiver.archive(file: "/Volumes/Optane/ClusterArchiver/testFile1.csv.lz")
    }

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
        // decompression: time sh -c 'find . -type f | xargs -I{} -P 4 $CLUSTERARCHIVER {}'  90.41s user 51.54s system 359% cpu 39.452 total
        
        // ClusterArchiver archive one command parallelized on corpus of 9449 files (28 local cores)
        // compression: time sh -c 'find . -type f | xargs -I{} -P 28 $CLUSTERARCHIVER {}'  567.69s user 302.42s system 2561% cpu 33.968 total
        // decompression: time sh -c 'find . -type f | xargs -I{} -P 28 $CLUSTERARCHIVER {}'  96.66s user 186.57s system 2075% cpu 13.645 total
        
        // Using BinaryCodable for messages to remote actors

        // 28 local cores, no remotes
        // compression: 9449 / 0 files in 32.379307985305786s, max concurrent 28
        // decompression: 9449 / 0 files in 5.861212968826294s, max concurrent 28
        
        // 172 remote cores
        // compression: 0 / 9449 files in 24.445824027061462s, max concurrent 172
        // decompression: 0 / 9449 files in 15.587779998779297s, max concurrent 172
        
        // 28 local cores / 172 remote cores
        // compression: 3449 / 6000 files in 14.823001980781555s, max concurrent 200
        // decompression: 5075 / 4374 files in 6.921328067779541s, max concurrent 200
        
        // Using JsonCodable for messages to remote actors
        
        // 172 remote cores
        // compression: 0 / 9449 files in 37.205869913101196s, max concurrent 172
        // decompression: 0 / 9449 files in 20.83649504184723s, max concurrent 172
        
        
        // Single large file (1.63 GB // 23.1 GB)
        // time lzip -d /Users/rjbowli/Desktop/TESTARCHIVE_LARGE/ProdGmailErrorLog20210315t0000-To-20210316t0000.csv.lz
        // lzip -d   254.11s user 10.42s system 38% cpu 11:18.83 total
        // ./minilzip -d   179.59s user 13.59s system 60% cpu 5:21.19 total
        // ./minilzip   3837.68s user 16.10s system 98% cpu 1:05:07.23 total
        
        
        // raspberry pi vs odroid
        
        // compress all remote: 0 / 9449 files in 32.590381026268005s, max concurrent 172
        // compress just the pis (19 nodes / 4cores / ~$1200): 0 / 9449 files in 44.54760408401489s, max concurrent 76
        // compress just the odroids (12 nodes / 8cores / ~$600): 0 / 9449 files in 46.167333006858826s, max concurrent 100
        
        // together:
        
        ClusterArchiver.archive(directory: "/Volumes/Optane/ClusterArchiver/TESTARCHIVE",
                                address: "0.0.0.0",
                                port: 9090)
    }
    
    func testLargeArchive2() throws {
        
        // 100k files, 798 bytes -> 6.6 MB
        
        // 28 local cores, no remotes
        // compression: 100000 / 0 files in 245.8698070049286s, max concurrent 28
        // decompression: 100000 / 0 files in 54.309731006622314s, max concurrent 28
        
        // 172 remote cores
        // compression: 0 / 100000 files in 205.94759500026703s, max concurrent 172
        // decompression: 0 / 100000 files in 135.33914601802826s, max concurrent 172
        
        // 28 local cores / 172 remote cores
        // compression: 42475 / 57525 files in 116.7931410074234s, max concurrent 200
        // decompression: 48035 / 51965 files in 57.78493404388428s, max concurrent 200
        
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
