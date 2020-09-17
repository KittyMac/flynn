import XCTest
import class Foundation.Bundle

// swiftlint:disable line_length

import ClusterCounterFramework

final class ClusterCounterTests: XCTestCase {

    func testSlave() throws {
        ClusterCounter.runAsSlave("127.0.0.1", 9090)
    }
    
    func testMaster() throws {
        ClusterCounter.runAsMaster("0.0.0.0", 9090)
    }

    static var allTests = [
        ("testSlave", testSlave),
        ("testMaster", testMaster),
    ]
}
