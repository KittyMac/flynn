//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

extension Flynn {
    
    private static var registeredActorsQueue = Queue<Actor>(size: 1024,
                                                            manyProducers: true,
                                                            manyConsumers: true)
    
    internal static func clearRegisteredActors() {
        registeredActorsQueue.clear()
    }
    
    internal static func register(_ actor: Actor) {
        // register is responsible for ensuring the actor is retained for a minimum amount of time. this is because
        // actors with chainable behaviors doing this ( Image().beDoSomething() ) Swift will dealloc the actor before
        // the behavior is called. So actors now register themselves when they are init'd, and Flynn ensures it is
        // retained for at least one second before it is allowed to deallocate naturally.
#if os(Linux)
        registeredActorsQueue.enqueue(actor)
#else
        _ = Unmanaged.passRetained(actor).autorelease()
#endif
    }
    
    internal static func checkRegisteredActors() {
#if os(Linux)
        let actorIsDone = { (actor: Actor) -> Bool in
            return actor.unsafeUptime >= 1.0
        }
        while registeredActorsQueue.dequeueIf(actorIsDone) != nil { }
#endif
    }
    
}
