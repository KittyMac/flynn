
// swiftlint:disable line_length

import XCTest

@testable import Flynn

class FlynnRemoteTests: XCTestCase {
    
    override func setUp() {
        
    }

    override func tearDown() {
        
    }

    func testSimpleRemote() {
        let expectation = XCTestExpectation(description: "RemoteActor is run and prints message")
        
        let port = Int32.random(in: 8000..<65500)
        Flynn.master("127.0.0.1", port)
        Flynn.slave("127.0.0.1", port, [Echo.self])
        Flynn.slave("127.0.0.1", port, [Echo.self])
        Flynn.slave("127.0.0.1", port, [Echo.self])
                
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
        
        Flynn.shutdown()
    }
    
    func testSlaveReconnect() {
        let expectation = XCTestExpectation(description: "RemoteActor is run and prints message")
        
        let port = Int32.random(in: 8000..<65500)
        
        Flynn.slave("127.0.0.1", port, [Echo.self])
        sleep(2)
        Flynn.master("127.0.0.1", port)
        sleep(2)
        
        Echo().beToLower("HELLO WORLD", Flynn.any) { (data) in
            if let lowered = String(data: data, encoding: .utf8) {
                if lowered == "hello world [1]" {
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        Flynn.shutdown()
    }

    static var allTests = [
        ("testSimpleRemote", testSimpleRemote),
    ]
}
