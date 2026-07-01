// flynn:ignore Reentrant ReturnCallbacks
// flynn:ignore Weak Timer Violation: Flynn.Timer callbacks should use [weak self]
// flynn:ignore Flynn.Any Warning: Flynn.any inside of an Actor; did you mean to use self?

import XCTest
import Flynn

// Tests the use case where a behaviour wants to run a bit of code synchronously
// before the behaviour message is sent proper
class SyncHeader: Actor {
    
    static internal func _preSync1(string: inout String,
                                   _ sender: Actor,
                                   _ returnCallback: inout (String) -> Void) {
        print("_preSync1[\(Thread.current)]: \(string)")
        string = string.lowercased()
        
        let localString = string
        let localReturnCallback = returnCallback
        
        Flynn.Timer(timeInterval: 1.0, immediate: false, repeats: false, sender) { timer in
            if (sender.unsafeUUID != Flynn.any.unsafeUUID) {
                fatalError("failed to run returnCallback on the correct sender")
            }
            localReturnCallback(localString)
        }
        returnCallback = { _ in print("BLOCKED") }
    }
    internal func _beSync1(string: String,
                           _ returnCallback: @escaping (String) -> Void) {
        print("_beSync1[\(Thread.current)]: \(string)")
        
        // will print "BLOCKED" as we disable it in the prefix
        returnCallback(string)
    }
    
    
    static internal func _preSync2(string: inout String) {
        print("_preSync2[\(Thread.current)]: \(string)")
        string = string.uppercased()
    }
    internal func _beSync2(string: String,
                           _ returnCallback: @escaping (String) -> Void) {
        print("_beSync2[\(Thread.current)]: \(string)")
        returnCallback(string)
    }

}
