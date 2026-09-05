// flynn:ignore Reentrant ReturnCallbacks

import XCTest
import Flynn

class ActorA: Actor {
    private let b = ActorB()
    private var counter = 0
    
    override init() {
        b.beAdd(x: counter, y: 1, Flynn.any) { result in
            // self.counter = result
        }
        
        let actor = Actor()
        b.beAdd(x: counter, y: 1, actor) { result in
            // self.counter = 0
        }
    }
    
    internal func _beIncrement() {
        // safe: self means the callback will run on myself (this actor)
        b.beAdd(x: counter, y: 1, self) { result in
            self.counter = result
        }
        
        // unsafe: callback will run on the Flynn.any actor and access the internal state
        // of myself (which could be running in a different thread concurrently)
        let actor = Actor()
        b.beAdd(x: counter, y: 1, actor) { result in
            // self.counter = 0
        }
    }
}

class ActorB: Actor {
    internal func _beAdd(x: Int, y: Int) -> Int {
        return x + y
    }
}
