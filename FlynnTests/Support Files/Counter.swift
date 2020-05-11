//
//  FlynnTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import XCTest

@testable import Flynn

class Counter: Actor {
    var counter:Int = 0
    lazy var inc = Behavior(self) { (args:BehaviorArgs) in
        let n:Int = args[0]
        self.counter += n
    }
    lazy var dec = Behavior(self) { (args:BehaviorArgs) in
        let n:Int = args[0]
        self.counter -= n
    }
    lazy var equals = Behavior(self) { (args:BehaviorArgs) in
        let callback:((Int) -> Void) = args[0]
        callback(self.counter)
    }
}
