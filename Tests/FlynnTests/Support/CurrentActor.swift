// flynn:ignore Unsafe Self Violation

import XCTest
import Foundation

@testable import Flynn

// Exercises Flynn.unsafeCurrentActor and the default-sender behaviour: when a
// behaviour with a callback is invoked from inside actor A without an explicit
// unsafeSender, the callback must be delivered on A.
class CurrentActorProbe: Actor {
    private let helper = CurrentActorHelper()
    private var counter = 0
    
    // (unsafeCurrentActor === self, this actor is executing)
    internal func _beProbe() -> (Bool, Bool) {
        return (Flynn.unsafeCurrentActor === self, unsafeIsExecuting)
    }
    
    // Calls helper with NO sender: callback must run on self and be able to
    // touch self's state safely. Reports whether it did.
    internal func _beDefaultSender(_ returnCallback: @escaping (Bool, Int) -> Void) {
        helper.beAdd(x: counter, y: 1) { result in
            self.counter = result   // safe iff we are executing on self
            returnCallback(self.unsafeIsExecuting, self.counter)
        }
    }
    
    // Calls helper with an explicit foreign sender: callback must NOT run on self.
    internal func _beExplicitSender(_ returnCallback: @escaping (Bool) -> Void) {
        let other = Actor()
        helper.beAdd(x: 1, y: 1, unsafeSender: other) { [unowned self] _ in
            let onSelf = self.unsafeIsExecuting
            let onOther = other.unsafeIsExecuting
            self.unsafeSend { _ in returnCallback(onSelf == false && onOther) }
        }
    }
}

class CurrentActorHelper: Actor {
    internal func _beAdd(x: Int, y: Int) -> Int {
        return x + y
    }
}
