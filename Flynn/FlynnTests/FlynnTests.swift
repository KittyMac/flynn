//
//  FlynnTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import XCTest

@testable import Flynn

class Foo: Actor {
    
    var counter:Int = 0
    
    lazy var increment = Behavior<Foo>(self) { (args:BehaviorArgs) in
        let n:Int = args[0]
        self.counter += n
    }
    
    lazy var decrement = Behavior<Foo>(self) { (args:BehaviorArgs) in
        let n:Int = args[0]
        self.counter -= n
    }
    
    lazy var result = Behavior<Foo>(self) { (args:BehaviorArgs) in
        let callback:((Int) -> Void) = args[0]
        callback(self.counter)
    }
}


class FlynnTests: XCTestCase {

    override func setUp() { }

    override func tearDown() { }

    func testExample() {
        Foo().increment(1)
            .increment(10)
            .increment(20)
            .decrement(1)
            .result() { (x:Int) in
                print("The result is \(x)")
            }
    }

    func testPerformanceExample() {
        self.measure { }
    }

}
