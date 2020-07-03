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
        Flynn.startup()
    }

    override func tearDown() {
        Flynn.shutdown()
    }

    func testScheduleActor1() {
        let expectation = XCTestExpectation(description: "Wait for counter to finish")
        let counter = Counter()
        counter.beHello("Rocco")
               .beInc(1)
               .beEquals { (value: Int) in
                    XCTAssertEqual(value, 1, "Counter did not add up to 1")
                    expectation.fulfill()
                }
        wait(for: [expectation], timeout: 10.0)
    }
}
