
// swiftlint:disable line_length

import XCTest

@testable import Flynn

class FlynnRemoteTests: XCTestCase {
    
    override func setUp() {
        Flynn.startup()
        
        let port = Int32.random(in: 8000..<65500)
        Flynn.master("127.0.0.1", port)
        Flynn.slave("127.0.0.1", port, [Echo.self])
        Flynn.slave("127.0.0.1", port, [Echo.self])
        Flynn.slave("127.0.0.1", port, [Echo.self])
    }

    override func tearDown() {
        Flynn.shutdown()
    }

    func testSimpleRemote() {
        let expectation = XCTestExpectation(description: "RemoteActor is run and prints message")
                
        Echo().bePrint("Hello Remote Actor 1!")
        Echo().bePrint("Hello Remote Actor 2!")
        Echo().bePrint("Hello Remote Actor 3!")
        
        let printReply: RemoteBehaviorReply = { (data) in
            if let lowered = String(data: data, encoding: .utf8) {
                print("on master: \(lowered)")
            }
        }
        
        let echo1 = Echo()
        echo1.beToLower("HELLO WORLD A", Flynn.any, printReply)
        echo1.beToLower("HELLO WORLD B", Flynn.any, printReply)
        
        let echo2 = Echo()
        echo2.beToLower("HELLO WORLD C", Flynn.any, printReply)
        echo2.beToLower("HELLO WORLD D", Flynn.any, printReply)
        
        let start = ProcessInfo.processInfo.systemUptime
        while (ProcessInfo.processInfo.systemUptime - start) < 5 { }
        
        expectation.fulfill()
    }

    static var allTests = [
        ("testSimpleRemote", testSimpleRemote),
    ]
}
