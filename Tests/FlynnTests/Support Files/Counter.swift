//
//  FlynnTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import XCTest

@testable import Flynn

// Actors are normal Swift classes who subclass the Flynn.Actor class.
// Flynn's goal is to provide all actors data-race, dead-lock free
// concurrency that is highly optimized for both your CPU and your
// memory. To do this, you should adhere to the following best
// practices when coding your actors.
//
// 1. All non-behavior members and functions in your actor should
// be marked as PRIVATE. If you attempt to directly access a member
// variable or function from outside of your actor class there are
// NO MORE GAURANTEES about the safety of your concurrency.
//
// 2. Behaviors are your actors inlet from the outside world. You
// can safely and freely call behaviors on any and all actors,
// from one actor to another actor, or from non-actor code to actor
// code and visa-versa. To implement a behavior, declare a closure
// to a lazy var of type Behavior, like this:
//
// lazy var hello = ChainableBehavior(self) { (args:BehaviorArgs) in print("hello world from " + args[x:0]) }
//
// Then other code can call that behavior as you would a method:
//
// myActor.hello("Rocco")
//
// Note: Your behaviors will ALWAYS execute on a background thread, and will NEVER execute on the
// main thread. As such, calling code which is inherently unsafe for concurrency will still be
// unsafe for concurrency in Flynn. You behavior calls are to a specific actor are gauraunteed
// to be executed sequentially and concurrently to other actors.

class Counter: Actor {
    private var counter: Int = 0

    private func apply(_ value: Int) {
        counter += value
    }

    lazy var beHello = ChainableBehavior(self) { (args: BehaviorArgs) in
        // flynnlint:parameter String - who is saying hello!
        print("hello world from " + args[x:0])
    }

    lazy var beInc = ChainableBehavior(self) { [unowned self] (args: BehaviorArgs) in
         // flynnlint:parameter Int - amount to increment by
        self.apply(args[x: 0])
    }
    lazy var beDec = ChainableBehavior(self) { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter Int - amount to decrement
        self.apply(-(args[x: 0]))
    }
    lazy var beEquals = ChainableBehavior(self) { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter ((Int) -> Void) - on complete closure
        let callback: ((Int) -> Void) = args[x:0]
        callback(self.counter)
    }
}
