
// swiftlint:disable line_length

import XCTest

@testable import Flynn

class Echo: RemoteActor {
    private func _bePrint(_ string: String) {
        print("from master: '\(string)'")
    }
    
    private func _beToLower(_ string: String) -> String {
        return string.lowercased()
    }
}

// TODO: FlynnLint will need to be able to autogenerate this...
// FlynnLint needs to be smart enough to autogenerate two things:
// 1. A behavior without a return value
//    This kind of behavior only needs to serialize arguments and send
// 2. A behavior with a return value
//    This kind of behavior needs to serialize arguments, send, but also call a
//    closure on a receiving actor (sender and closure get added as last two arguments
//    on the external behavior.

extension Echo {
        
    struct bePrintMessage: Codable {
        let arg0: String
    }
        
    public func bePrint(_ string: String) {
        let msg = bePrintMessage(arg0: string)
        if let data = try? JSONEncoder().encode(msg) {
            unsafeSendToRemote("Echo", "bePrint", data, nil, nil)
        }else{
            fatalError()
        }
    }
    
    struct beToLowerMessage: Codable {
        let arg0: String
    }
    
    public func beToLower(_ string: String, _ sender: Actor, _ callback: @escaping () -> Void) {
        let msg = beToLowerMessage(arg0: string)
        if let data = try? JSONEncoder().encode(msg) {
            unsafeSendToRemote("Echo", "beToLower", data, sender, callback)
        }else{
            fatalError()
        }
    }
    
    func unsafeRegisterAllBehaviors() {
        safeRegisterRemoteBehavior("bePrint") { [unowned self] (data) in
            if let msg = try? JSONDecoder().decode(bePrintMessage.self, from: data) {
                self._bePrint(msg.arg0)
            }
            return nil
        }
        
        safeRegisterRemoteBehavior("beToLower") { [unowned self] (data) in
            if let msg = try? JSONDecoder().decode(beToLowerMessage.self, from: data) {
                _ = self._beToLower(msg.arg0)
            }
            return nil
        }
    }
}

class FlynnRemoteTests: XCTestCase {
    
    override func setUp() {
        Flynn.startup()
        
        let port = Int32.random(in: 8000..<65500)
        Flynn.master("127.0.0.1", port)
        Flynn.slave("127.0.0.1", port)
        Flynn.slave("127.0.0.1", port)
        Flynn.slave("127.0.0.1", port)
    }

    override func tearDown() {
        Flynn.shutdown()
    }

    func testSimpleRemote() {
        let expectation = XCTestExpectation(description: "RemoteActor is run and prints message")
        
        Flynn.registerRemoteActor(Echo.self)
        
        Echo().bePrint("Hello Remote Actor 1!")
        Echo().bePrint("Hello Remote Actor 2!")
        Echo().bePrint("Hello Remote Actor 3!")
        
        let start = ProcessInfo.processInfo.systemUptime
        while (ProcessInfo.processInfo.systemUptime - start) < 5 { }
        
        expectation.fulfill()
    }

    static var allTests = [
        ("testSimpleRemote", testSimpleRemote),
    ]
}
