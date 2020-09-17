import XCTest
import class Foundation.Bundle

// swiftlint:disable line_length

import ClusterCounterFramework

final class ClusterCounterTests: XCTestCase {

    func testNode() throws {
        ClusterCounter.runAsNode("127.0.0.1", 9090)
    }
    
    func testRoot() throws {
        ClusterCounter.runAsRoot("0.0.0.0", 9090)
    }

    static var allTests = [
        ("testNode", testNode),
        ("testRoot", testRoot),
    ]
}
