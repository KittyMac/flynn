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
    lazy var println : Behavior = Behavior(self) { [weak self] (args:BehaviorArgs) in
        print("\(args.count)")
    }
}


class FlynnTests: XCTestCase {

    override func setUp() { }

    override func tearDown() { }

    func testExample() {
                
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let foo = Foo()
        foo.println(1)
        foo.println(1, 2)
        foo.println(1, 2, 3)
        foo.println(1, 2, 3, 4)
        print("here")
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
