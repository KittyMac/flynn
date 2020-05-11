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
    lazy var inc = Behavior<Counter>(self) { (args:BehaviorArgs) in
        let n:Int = args[0]
        self.counter += n
    }
    lazy var dec = Behavior<Counter>(self) { (args:BehaviorArgs) in
        let n:Int = args[0]
        self.counter -= n
    }
    lazy var equals = Behavior<Counter>(self) { (args:BehaviorArgs) in
        let callback:((Int) -> Void) = args[0]
        callback(self.counter)
    }
}

class StringBuilder: Actor {
    var string:String = ""
    lazy var append = Behavior<StringBuilder>(self) { (args:BehaviorArgs) in
        let a:String = args[0]
        self.string.append(a)
    }
    lazy var space = Behavior<StringBuilder>(self) { (args:BehaviorArgs) in
        self.string.append(" ")
    }
    lazy var result = Behavior<StringBuilder>(self) { (args:BehaviorArgs) in
        let callback:((String) -> Void) = args[0]
        callback(self.string)
    }
}


class FlynnTests: XCTestCase {

    override func setUp() { }

    override func tearDown() { }

    func test1() {
        let expectation = XCTestExpectation(description: "Wait for counter to finish")
        Counter()
            .inc(1)
            .inc(10)
            .inc(20)
            .dec(1)
            .equals() { (x:Int) in
                XCTAssertEqual(x, 30, "Counter did not add up to 30")
                expectation.fulfill()
            }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func test2() {
        let expectation = XCTestExpectation(description: "Wait for string builder to finish")
        StringBuilder()
            .append("hello")
            .space()
            .append("world")
            .result() { (s:String) in
                XCTAssertEqual(s, "hello world", "string did not append in the correct order")
                expectation.fulfill()
            }
        wait(for: [expectation], timeout: 10.0)
    }

    func testPerformanceExample() {
        self.measure { }
    }

}
