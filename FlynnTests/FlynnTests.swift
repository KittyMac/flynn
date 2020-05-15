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

    override func setUp() {
        Actor.startup()
    }

    override func tearDown() {
        Actor.shutdown()
    }

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
                
        let pipeline = Passthrough() |> Uppercase() |> Concatenate() |> Callback({ (args:BehaviorArgs) in
            let s:String = args.get(0)
            XCTAssertEqual(s, "HELLO WORLD", "chaining actors did not work as intended")
            expectation.fulfill()
        })
        
        pipeline.chain("hello")
        pipeline.chain(" ")
        pipeline.chain("world")
        pipeline.chain()
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testLoadBalancing() {
        self.measure {
            let expectation = XCTestExpectation(description: "Load balancing")
            
            let pipeline = Passthrough() |> Array(count: 128) { Uppercase() } |> Concatenate() |> Callback({ (args:BehaviorArgs) in
                let s:String = args.get(0)
                XCTAssertEqual(s.count, 50000, "load balancing did not contain the expected number of characters")
                expectation.fulfill()
            })
            
            for i in 0..<50000 {
                if i % 2 == 0 {
                    pipeline.chain("x")
                } else {
                    pipeline.chain("o")
                }
                pipeline.wait(100)
            }
            
            pipeline.chain()
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    func testMeasureOverheadAgainstLoadBalancingExample() {
        // What we are attempting to determine is, in this "worst case scenario", how much overhead
        // is there in our actor/model system.
        self.measure {
            var combined:String = ""
            for i in 0..<50000 {
                if i % 2 == 0 {
                    combined.append("x".uppercased())
                } else {
                    combined.append("o".uppercased())
                }
            }
        }
    }
    
    func testMemoryBloatFromMessagePassing() {
        
        let expectation = XCTestExpectation(description: "Memory overhead in calling behaviors")
        
        let pipeline = Passthrough() |> Array(count: 128) { Passthrough() } |> Passthrough() |> Callback({ (args:BehaviorArgs) in
            //let s:String = args.get(0)
            //XCTAssertEqual(s.count, 22250000, "load balancing did not contain the expected number of characters")
            if args.isEmpty {
                expectation.fulfill()
            }
        })
        
        for i in 0..<5000000 {
            if i % 2 == 0 {
                pipeline.chain(1)
            } else {
                pipeline.chain(2)
            }
            pipeline.wait(10)
        }
        
        pipeline.chain()
        wait(for: [expectation], timeout: 30.0)
    }
    
    func testMemoryBloatFromMessagePassing2() {
        let c = Counter()
        for _ in 0..<5000000 {
            c.inc(1).inc(1).inc(1).inc(1).inc(1).inc(1).inc(1).inc(1).inc(1).inc(1).inc(1).inc(1)
            c.wait(100)
        }
    }
    
}
