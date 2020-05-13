//
//  PonyRTTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import XCTest
import Flynn

class PonyRTTests: XCTestCase {

    override func setUp() {
        Actor.startup()
    }

    override func tearDown() {
        Actor.shutdown()
    }

    func testScheduleActor1() {
        let expectation = XCTestExpectation(description: "Wait for counter to finish")
        Counter()
            .inc(1)
            .equals() { (x:Int) in
                XCTAssertEqual(x, 1, "Counter did not add up to 30")
                expectation.fulfill()
            }
        wait(for: [expectation], timeout: 10.0)
    }


}
