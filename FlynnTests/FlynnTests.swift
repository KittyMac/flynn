//
//  FlynnTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import XCTest

@testable import Flynn

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
    
    func testFlowable() {
        let expectation = XCTestExpectation(description: "Flowable actors")
        
        /*
        let pipeline = Passthrough().target(
            Passthrough().target(
                Passthrough().target(
                    Print()
                )
            )
        )*/
        
        let pipeline = Passthrough().target(Print())
        
        pipeline.chain("hello")
        
        //pipeline.flow("hello")
        
    }
/*
    func testPerformanceExample() {
        self.measure { }
    }
 */

}
