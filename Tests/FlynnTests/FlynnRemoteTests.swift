
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
        Flynn.Root.listen("127.0.0.1", port, [])
        
        Flynn.Node.connect("127.0.0.1", port, [Echo.self])
        Flynn.Node.connect("127.0.0.1", port, [Echo.self])
        Flynn.Node.connect("127.0.0.1", port, [Echo.self])
        
        while (Flynn.remoteCores == 0) {
            usleep(500)
        }
                
        Echo().bePrint("Hello Remote Actor 1!")
        Echo().bePrint("Hello Remote Actor 2!")
        Echo().bePrint("Hello Remote Actor 3!")
        
        let printReply: RemoteBehaviorReply = { (data) in
            if let lowered = String(data: data, encoding: .utf8) {
                print("on root: \(lowered)")
                
                if lowered.hasPrefix("hello world d") {
                    expectation.fulfill()
                }
            }
        }
        
        let echo1 = Echo()
        echo1.beToLower("HELLO WORLD A", Flynn.any, printReply)
        echo1.beToLower("HELLO WORLD B", Flynn.any, printReply)
        
        let echo2 = Echo()
        echo2.beToLower("HELLO WORLD C", Flynn.any, printReply)
        echo2.beToLower("HELLO WORLD D", Flynn.any, printReply)
        
        wait(for: [expectation], timeout: 10.0)
        
        Flynn.shutdown()
    }
    
    func testNodeReconnect() {
        let expectation = XCTestExpectation(description: "Confirm nodes continuously try to connect")
        
        let port = Int32.random(in: 8000..<65500)
        
        Flynn.Node.connect("127.0.0.1", port, [Echo.self])
        sleep(2)
        Flynn.Root.listen("127.0.0.1", port, [])
        
        // Right now this is necessary, we need to wait until
        // we know the node is connected before using remote actors
        while (Flynn.remoteCores == 0) {
            usleep(500)
        }
        
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
    
    func testNodeRunOnAllCores() {
        let expectation = XCTestExpectation(description: "Confirm remote actors use all cores on remote node")
        
        let port = Int32.random(in: 8000..<65500)
        
        Flynn.Root.listen("127.0.0.1", port, [])
        
        Flynn.Node.connect("127.0.0.1", port, [Echo.self])
        
        while (Flynn.remoteCores == 0) {
            usleep(500)
        }
        
        var n = 0
        for _ in 0..<Flynn.remoteCores {
            Echo().bePrintThreadName(Flynn.any) { (data) in
                n += 1
                if n >= Flynn.remoteCores {
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        Flynn.shutdown()
    }
    
    func testRemoteService() {
        let expectation = XCTestExpectation(description: "RemoteActor as a service")
        
        // The idea behind remote services is that you can have a single, shared actor
        // pre-existing on a remote node. The remote node then shares this existing actor
        // with root nodes that it connects to, allowing code on that root node to
        // access that specific RemoteActor remotely.
        
        let echoServiceName = "SHARED ECHO SERVICE"
        
        let port = Int32.random(in: 8000..<65500)
        
        Flynn.Node.connect("127.0.0.1", port, [Echo.self])
        Flynn.Node.registerActorsWithRoot([Echo(echoServiceName)])
        
        Flynn.Root.listen("127.0.0.1", port, [Echo.self])
        
        // Wait until the node has connected
        while (Flynn.remoteCores == 0) {
            usleep(500)
        }
        
        // Wait until the shared service has been
        // communicated to the root node
        var echoService: Echo?
        while (echoService == nil) {
            Flynn.Root.remoteActorByUUID(echoServiceName, Flynn.any) { echoService = $0 as? Echo }
            usleep(500)
        }
        
        
        let printReply: RemoteBehaviorReply = { (data) in
            if let lowered = String(data: data, encoding: .utf8) {
                print("on root: \(lowered)")
                
                if lowered.hasPrefix("hello world d") {
                    expectation.fulfill()
                }
            }
        }
                
        if let echoService = echoService {
            echoService.beToLower("HELLO WORLD A", Flynn.any, printReply)
            echoService.beToLower("HELLO WORLD B", Flynn.any, printReply)
            echoService.beToLower("HELLO WORLD C", Flynn.any, printReply)
            echoService.beToLower("HELLO WORLD D", Flynn.any, printReply)
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        Flynn.shutdown()
    }
    

    static var allTests = [
        ("testSimpleRemote", testSimpleRemote),
    ]
}
