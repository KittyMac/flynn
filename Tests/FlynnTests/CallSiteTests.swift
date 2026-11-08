import XCTest

import Flynn

class CallSiteTests: XCTestCase {

    override func setUp() {
        Flynn.startup()
        Flynn.CallSites.start()
    }

    override func tearDown() {
        Flynn.CallSites.stop()
        Flynn.shutdown()
    }

    private func live(_ file: StaticString, _ line: UInt) -> Int {
        let callSite = "\(file):\(line)"
        return Flynn.CallSites.top(1000).first { $0.callSite == callSite }?.live ?? 0
    }

    private func waitForLive(_ expected: Int, _ file: StaticString, _ line: UInt) -> Int {
        let deadline = Date().addingTimeInterval(5)
        var value = live(file, line)
        while value != expected && Date() < deadline {
            usleep(1000)
            value = live(file, line)
        }
        return value
    }

    func testBehaviourRecordsCallerCallSite() {
        let counter = Counter()
        counter.unsafeSuspend()

        let sendLine: UInt = #line + 2
        for _ in 0..<100 {
            counter.beInc(1)
        }

        // all 100 queued messages are attributed to the line above, not to FlynnPlugin.swift
        XCTAssertEqual(live(#file, sendLine), 100)
        XCTAssertFalse(Flynn.CallSites.top().contains { $0.callSite.contains("FlynnPlugin.swift") })

        counter.unsafeResume()
        XCTAssertEqual(waitForLive(0, #file, sendLine), 0)
    }

    func testReplyIsAttributedToOriginalCallSite() {
        let counter = Counter()
        let receiver = Counter()
        receiver.unsafeSuspend()

        let expectation = XCTestExpectation(description: "reply")
        let sendLine: UInt = #line + 1
        counter.beGetValue(receiver) { _ in expectation.fulfill() }

        // the request runs on counter; its reply waits in the suspended receiver's
        // mailbox and is still attributed to the original call above
        XCTAssertEqual(waitForLive(1, #file, sendLine), 1)

        receiver.unsafeResume()
        wait(for: [expectation], timeout: 5)
        XCTAssertEqual(waitForLive(0, #file, sendLine), 0)
    }

    func testProtocolDispatchStillWorks() {
        // Timerable.beTimerFired is a protocol requirement; it must still be satisfied
        // by the generated exact-signature overload
        let counter = Counter()
        let timer = Flynn.Timer(timeInterval: 0.01, repeats: false, counter, [5])
        let target: Timerable = counter
        target.beTimerFired(timer, [5])

        let expectation = XCTestExpectation(description: "value")
        usleep(200_000)
        counter.beGetValue(Flynn.any) { value in
            XCTAssertEqual(value, 10)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }
}
