// swiftlint:disable nesting

import XCTest
import Flynn

class FlynnComponentsTests: XCTestCase {

    override func setUp() {
        Flynn.startup()
    }

    override func tearDown() {
        Flynn.shutdown()
    }

    func testQueue() {

        self.measure {

            let queue = Queue<NSString>(size: 64)

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
        let queue = Queue<Actor>(size: 50000)

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
        while let _ = queue.dequeue() as? PassToMe {
            count += 1
        }

        XCTAssert(count == 100)
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
            let queue = Queue<SimpleInt>(size: 64)
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
            let queue = Queue<SimpleInt>(size: 64)

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
