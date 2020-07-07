//
//  FlynnTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// swiftlint:disable line_length

import XCTest

@testable import Flynn

class FlynnTests: XCTestCase {

    override func setUp() {
        Flynn.startup()
    }

    override func tearDown() {
        Flynn.shutdown()
    }

    func test1() {
        let expectation = XCTestExpectation(description: "Wait for counter to finish")

        print("start")
        Counter()
            .beInc(1)
            .beInc(10)
            .beInc(20)
            .beDec(1)
            .beEquals { (value: Int) in
                print("value: \(value)")
                XCTAssertEqual(value, 30, "Counter did not add up to 30")
                expectation.fulfill()
            }
        print("end")
        wait(for: [expectation], timeout: 10.0)
    }

    func test2() {
        let expectation = XCTestExpectation(description: "Wait for string builder to finish")

        let hello = "hello"

        StringBuilder()
            .beAppend(hello)
            .beSpace()
            .beAppend("world")
            .beResult { (value: String) in
                XCTAssertEqual(value, "hello world", "string did not append in the correct order")
                expectation.fulfill()
            }
        wait(for: [expectation], timeout: 10.0)
    }

    func testPassByReferenceCheck() {
        let expectation = XCTestExpectation(description: "Warning when passing reference values")

        Flynn.checkForUnsafeArguments = true

        PassToMe()
            .beString("Swift String")
            .beNSString("NSString" as NSString)

        Flynn.checkForUnsafeArguments = false

        expectation.fulfill()
    }

    func testColor() {
        let expectation = XCTestExpectation(description: "Protocols, extensions etc...")
        let color = Color()
            .beAlpha()
            .beColor()
            .beAlpha()
            .beColor()
            .beAlpha()
            .beColor()
            .beAlpha()
            .beColor()

        color.beGetColor( Behavior(color) { (args: BehaviorArgs) in
            let color: [Float] = args[x:0]
            print("color is \(color)")
        })
        color.beGetColor(color.beSetColor)
        color.beRender(CGRect.zero)

        //print(color.safeColorable._color)
        expectation.fulfill()
    }

    func testImage() {
        let expectation = XCTestExpectation(description: "Protocols, extensions etc...")
        Image()
            .beAlpha()
            .beColor()
            .beAlpha()
            .bePath("bundle://image.png")
        //print(color.safeColorable._color)
        expectation.fulfill()
    }

    func testFlowable() {
        let expectation = XCTestExpectation(description: "Flowable actors")

        let pipeline = Passthrough() |> Uppercase() |> Concatenate() |> Callback({ (args: BehaviorArgs) in
            let value: String = args[x:0]
            print(value)
            XCTAssertEqual(value, "HELLO WORLD", "chaining actors did not work as intended")
            expectation.fulfill()
        })

        pipeline.beFlow("hello")
        pipeline.beFlow(" ")
        pipeline.beFlow("world")
        pipeline.beFlow()
        wait(for: [expectation], timeout: 10.0)
    }

    func testLoadBalancing() {
        self.measure {
            let expectation = XCTestExpectation(description: "Load balancing")

            let pipeline = Passthrough() |> Array(count: Flynn.cores) { Uppercase() } |> Concatenate() |> Callback({ (args: BehaviorArgs) in
                let value: String = args[x:0]
                XCTAssertEqual(value.count, 50000, "load balancing did not contain the expected number of characters")
                expectation.fulfill()
            })

            for num in 0..<50000 {
                if num % 2 == 0 {
                    pipeline.beFlow("x")
                } else {
                    pipeline.beFlow("o")
                }
                //pipeline.wait(100)
            }

            pipeline.beFlow()

            wait(for: [expectation], timeout: 30.0)
        }
    }

    func testMeasureOverheadAgainstLoadBalancingExample() {
        // What we are attempting to determine is, in this "worst case scenario", how much overhead
        // is there in our actor/model system.
        self.measure {
            let stringX = "x"
            let stringO = "o"
            var combined: String = ""
            for num in 0..<50000 {
                if num % 2 == 0 {
                    combined.append(stringX.uppercased())
                } else {
                    combined.append(stringO.uppercased())
                }
            }
        }
    }

    func testMemoryBloatFromMessagePassing() {

        let expectation = XCTestExpectation(description: "Memory overhead in calling behaviors")

        let pipeline = Passthrough() |> Array(count: Flynn.cores) { Passthrough() } |> Passthrough() |> Callback({ (args: BehaviorArgs) in
            //let s:String = args[x:0]
            //XCTAssertEqual(s.count, 22250000, "load balancing did not contain the expected number of characters")
            if args.isEmpty {
                expectation.fulfill()
            }
        })

        for num in 0..<50000 {
            if num % 2 == 0 {
                pipeline.beFlow(1)
            } else {
                pipeline.beFlow(2)
            }
            pipeline.unsafeWait(0)
        }

        pipeline.beFlow()
        wait(for: [expectation], timeout: 30.0)
    }

    func testMemoryBloatFromMessagePassing2() {
        let counter = Counter()
        for _ in 0..<50000 {
            counter.beInc(1).beInc(1).beInc(1).beInc(1).beInc(1).beInc(1).beInc(1).beInc(1).beInc(1).beInc(1).beInc(1).beInc(1)
            counter.unsafeWait(10)
        }
    }

    static var allTests = [
        ("test1", test1),
        ("test2", test2),
        ("testPassByReferenceCheck", testPassByReferenceCheck),
        ("testColor", testColor),
        ("testImage", testImage),
        ("testFlowable", testFlowable),
        ("testLoadBalancing", testLoadBalancing),
        ("testMeasureOverheadAgainstLoadBalancingExample", testMeasureOverheadAgainstLoadBalancingExample),
        ("testMemoryBloatFromMessagePassing", testMemoryBloatFromMessagePassing),
        ("testMemoryBloatFromMessagePassing2", testMemoryBloatFromMessagePassing2)
    ]
}
