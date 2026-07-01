// flynn:ignore Reentrant ReturnCallbacks

import XCTest
import Flynn

// Tests the use case where a behaviour wants to run a bit of code synchronously
// before the behaviour message is sent proper
class SyncHeader: Actor {
    
    static internal func _preSync1(string: String) -> (String) {
        print("_preSync1[\(Thread.current)]: \(string)")
        return (string.lowercased())
    }
    internal func _beSync1(string: String,
                           _ returnCallback: @escaping (String) -> Void) {
        print("_beSync1[\(Thread.current)]: \(string)")
        returnCallback(string)
    }
    
    
    static internal func _preSync2(string: String) -> (String)  {
        print("_preSync2[\(Thread.current)]: \(string)")
        return (string.uppercased())
    }
    internal func _beSync2(string: String,
                           _ returnCallback: @escaping (String) -> Void) {
        print("_beSync2[\(Thread.current)]: \(string)")
        returnCallback(string)
    }

}
