// flynn:ignore Reentrant ReturnCallbacks

import XCTest
import Flynn

class ActorA: Actor {
    private let b = ActorB()
    private var counter = 0
    
    internal func _beIncrement() {
        let actor = Actor()
        
        // safe: self means the callback will run on myself (this actor)
        b.beAdd(x: counter, y: 1) { result in
            self.counter = result
        }
        
        Flynn.Timer(timeInterval: 1, immediate: true, repeats: true, unsafeSender: self) { [weak self] _ in
            self?.unsafePriority = 1
        }
        
        Flynn.Timer(timeInterval: 1, immediate: true, repeats: true, unsafeSender: actor) { _ in
            // self?.unsafePriority = 1
        }
        
        // unsafe: callback will run on the Flynn.any actor and access the internal state
        // of myself (which could be running in a different thread concurrently)
        
        b.beAdd(x: counter, y: 1, unsafeSender: actor) { result in
            // self.counter = 0
        }
        
        
    }
}

class ActorB: Actor {
    internal func _beAdd(x: Int, y: Int) -> Int {
        return x + y
    }
}
