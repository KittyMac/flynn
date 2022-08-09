## Coexisting with Swift Concurrency

NOTE: Additional features to work gracefully with Swift Concurrency (async/await) is a work-in-progress.

## Using async/await in Flynn actors

Flynn provides actor/model functionality from both synchronous and asynchrous Swift contexts as all of Flynn's calling mechanisms are implemented using regular synchronous methods and callbacks.

You may, however, want to be able to call async methods from inside of a Flynn actor, while still preserving in the thread safety of the Flynn actor. To do this, we have a mechanism very similar in behaviour to withCheckedContinuation, called **safeTask**.

```swift
class SwiftConcurrencyTestActor: Actor {

    private var x = 0

    internal func _beCheckFlynnTask() -> Int {
        
        // Safe: this is protected by Flynn already
        x += 1
        
        safeTask { continuation in
            
            // Safe: the Flynn actor is "suspended" during this
            // block. While the actor is suspended it will not
            // be scheduled to run in the Flynn runtime, allowing
            // the Swift async context sole access to the thread
            // safe Actor. It is YOUR responsibility to call the
            // continuation call back EXACTLY ONCE, which will
            // resume Flynn operations on this actor. Calling it
            // more than once will result in a fatal error. Not
            // calling it at all will leave this actor suspended
            // forever.
            //
            // Note: you may not call safeTask multiple times in the
            // same behavior.
            self.x += 1
            
            continuation()
        }
        
        // Safe: this is protected because the safeTask
        // block will not run until after the Flynn
        // actor is suspended. This happens when we
        // return from this behaviour's scope
        x += 1
        
        return x
    }
}
```
