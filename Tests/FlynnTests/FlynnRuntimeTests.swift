//
//  FlynnRuntimeTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// swiftlint:disable nesting

import XCTest
import Flynn

class FlynnRuntimeTests: XCTestCase {

    override func setUp() {
        Flynn.startup()
    }

    override func tearDown() {
        Flynn.shutdown()
    }

    func testQueue() {

        self.measure {

            let queue = Queue<NSString>(64)

            let concurrentQueue = DispatchQueue(label: "test.concurrent.queue", attributes: .concurrent)

            var correct: Int32 = 0
            for idx in 0..<20000 {
                correct += Int32(idx)

                concurrentQueue.async {
                    queue.enqueue("\(idx)" as NSString)
                }
            }

            var total: Int32 = 0

            while total != correct {
                while let numberString = queue.dequeue() {
                    total += numberString.intValue
                }
            }

            XCTAssert(total == correct)
        }
    }

    func testActorQueue() {
        let queue = Queue<Actor>(50000)

        let concurrentQueue = DispatchQueue(label: "test.concurrent.queue", attributes: .concurrent)

        for _ in 0..<100 {
            concurrentQueue.async {
                queue.enqueue(PassToMe())
            }
        }

        while queue.count < 100 {
            usleep(500)
        }

        var count = 0
        while let actor = queue.dequeue() as? PassToMe {
            actor.unsafePrint("hello \(count)!")
            count += 1
        }

        XCTAssert(count == 100)
    }

    func testScheduleActor1() {
        let expectation = XCTestExpectation(description: "Wait for counter to finish")
        let counter = Counter()
        counter.beHello("Rocco")
               .beInc(1)
                .beInc(2)
                .beInc(3)
                .beInc(4)
                .beInc(5)
                .beInc(6)
                .beInc(7)
                .beInc(8)
               .beEquals { (value: Int) in
                    XCTAssertEqual(value, 36, "Counter did not add up to 1")
                    expectation.fulfill()
                }
        wait(for: [expectation], timeout: 10.0)
    }

    func testSortableQueue() {

        class SimpleInt: ExpressibleByIntegerLiteral {
            typealias IntegerLiteralType = Int
            var value: Int = 0

            required init(integerLiteral value: Int) {
                self.value = value
            }
        }

        self.measure {
            let queue = Queue<SimpleInt>(64)
            let compareSimpleInts = { (lhs: SimpleInt, rhs: SimpleInt) -> Bool in
                return lhs.value > rhs.value
            }

            queue.enqueue(5, sortedBy: compareSimpleInts)
            queue.enqueue(2, sortedBy: compareSimpleInts)
            queue.enqueue(17, sortedBy: compareSimpleInts)
            queue.enqueue(15, sortedBy: compareSimpleInts)
            queue.enqueue(99, sortedBy: compareSimpleInts)
            queue.enqueue(0, sortedBy: compareSimpleInts)

            var string = ""
            while let value = queue.dequeue() {
                string.append("\(value.value),")
            }

            XCTAssert(string == "0,2,5,15,17,99,")
        }
    }

    func testDequeueAny() {

        class SimpleInt: ExpressibleByIntegerLiteral {
            typealias IntegerLiteralType = Int
            var value: Int = 0

            required init(integerLiteral value: Int) {
                self.value = value
            }
        }

        self.measure {
            let queue = Queue<SimpleInt>(64)

            queue.enqueue(5)
            queue.enqueue(2)
            queue.enqueue(17)
            queue.enqueue(15)
            queue.enqueue(99)
            queue.enqueue(0)

            queue.dequeueAny { (item) -> Bool in
                return item.value == 17 || item.value == 15 || item.value == 0
            }

            var string = ""
            while let value = queue.dequeue() {
                string.append("\(value.value),")
            }

            XCTAssert(string == "5,2,99,")
        }
    }
}
