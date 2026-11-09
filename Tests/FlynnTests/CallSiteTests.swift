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
        // Timerable.beTimerFired is a protocol requirement, satisfied by the generated
        // call-site behaviour
        let counter = Counter()
        let timer = Flynn.Timer(timeInterval: 0.01, repeats: false, counter, [5])
        let target: Timerable = counter
        target.beTimerFired(timer, [5], #file, #line)

        let expectation = XCTestExpectation(description: "value")
        usleep(200_000)
        counter.beGetValue(Flynn.any) { value in
            XCTAssertEqual(value, 10)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func testTimerableTimerIsAttributedToCreator() {
        let counter = Counter()
        counter.unsafeSuspend()

        let createLine: UInt = #line + 1
        Flynn.Timer(timeInterval: 0.01, repeats: false, counter, [5])

        XCTAssertEqual(waitForLive(1, #file, createLine), 1)
        XCTAssertFalse(Flynn.CallSites.top().contains { $0.callSite.contains("Flynn+Timer.swift") })
        XCTAssertFalse(Flynn.CallSites.top().contains { $0.callSite.contains("FlynnPlugin.swift") })

        counter.unsafeResume()
        XCTAssertEqual(waitForLive(0, #file, createLine), 0)
    }

    func testCallbackTimerIsAttributedToCreator() {
        let counter = Counter()
        counter.unsafeSuspend()

        let createLine: UInt = #line + 1
        Flynn.Timer(timeInterval: 0.01, repeats: false, counter) { _ in }

        XCTAssertEqual(waitForLive(1, #file, createLine), 1)
        XCTAssertFalse(Flynn.CallSites.top().contains { $0.callSite.contains("Flynn+Timer.swift") })

        counter.unsafeResume()
        XCTAssertEqual(waitForLive(0, #file, createLine), 0)
    }

    func testProtocolCallIsAttributedToBehaviour() {
        // Viewable.beRender is a protocol requirement without call site parameters, so
        // the caller is unknown; the message is labelled with the behaviour instead
        let color = Color()
        color.unsafeSuspend()

        let viewable: Viewable = color
        viewable.beRender()

        let samples = Flynn.CallSites.top()
        XCTAssertTrue(samples.contains { $0.callSite == "Viewable.beRender (via protocol)" && $0.live == 1 },
                      "\(samples)")
        XCTAssertFalse(samples.contains { $0.callSite.contains("FlynnPlugin.swift") })

        color.unsafeResume()
        color.unsafeWait()
    }

    func testFlowableProtocolCallIsAttributedToCaller() {
        // Flowable.beFlow carries call site parameters, and the protocol extension keeps
        // the one-argument call working through the protocol type
        let passthrough = Passthrough()
        passthrough.unsafeSuspend()

        let flowable: Flowable = passthrough
        let callLine: UInt = #line + 1
        flowable.beFlow(["x"])

        XCTAssertEqual(live(#file, callLine), 1)
        XCTAssertFalse(Flynn.CallSites.top().contains { $0.callSite.contains("via protocol") })

        passthrough.unsafeResume()
        XCTAssertEqual(waitForLive(0, #file, callLine), 0)
    }

    func testFlowableConcreteCallIsAttributedToCaller() {
        // on the concrete type, the generated behaviour must win over the protocol extension
        let passthrough = Passthrough()
        passthrough.unsafeSuspend()

        let callLine: UInt = #line + 1
        passthrough.beFlow(["x"])

        XCTAssertEqual(live(#file, callLine), 1)

        passthrough.unsafeResume()
        XCTAssertEqual(waitForLive(0, #file, callLine), 0)
    }

    func testFlowablePipelineIsAttributedToSendingStage() {
        // a message flowing from one stage to the next is attributed to the line in the
        // upstream stage's _beFlow that called safeFlowToNextTarget
        let first = Passthrough()
        let second = Passthrough()
        second.unsafeSuspend()
        first |> second

        first.beFlow(["x"])
        first.unsafeWait()

        let deadline = Date().addingTimeInterval(5)
        var samples = Flynn.CallSites.top()
        while samples.contains(where: { $0.callSite.hasSuffix("Support/Flowable.swift:11") }) == false && Date() < deadline {
            usleep(1000)
            samples = Flynn.CallSites.top()
        }
        XCTAssertTrue(samples.contains { $0.callSite.hasSuffix("Support/Flowable.swift:11") && $0.live == 1 },
                      "\(samples)")
        XCTAssertFalse(samples.contains { $0.callSite.contains("Sources/Flynn/Flowable.swift") })

        second.unsafeResume()
        second.unsafeWait()
    }

    func testTimerableProtocolCallStillCompiles() {
        // the protocol extension keeps the two-argument call working through the protocol type
        let counter = Counter()
        counter.unsafeSuspend()
        let timer = Flynn.Timer(timeInterval: 60, repeats: false, counter, [5])
        timer.cancel()

        let target: Timerable = counter
        let callLine: UInt = #line + 1
        target.beTimerFired(timer, [5], #file, #line)

        XCTAssertEqual(live(#file, callLine), 1)

        counter.unsafeResume()
        XCTAssertEqual(waitForLive(0, #file, callLine), 0)
    }

    func testGroupNotifyIsAttributedToCaller() {
        let counter = Counter()
        counter.unsafeSuspend()

        let group = Flynn.Group()
        group.enter()
        let notifyLine: UInt = #line + 1
        group.notify(actor: counter) { }
        group.leave()

        XCTAssertEqual(waitForLive(1, #file, notifyLine), 1)
        XCTAssertFalse(Flynn.CallSites.top().contains { $0.callSite.contains("Flynn+Group.swift") })

        counter.unsafeResume()
        XCTAssertEqual(waitForLive(0, #file, notifyLine), 0)
    }

    func testGroupNotifyWhenEmptyDoesNotHoldLock() {
        // notify() on a group with nothing outstanding used to return without
        // unlocking, so the next enter() deadlocked
        let group = Flynn.Group()
        let expectation = XCTestExpectation(description: "notified")
        group.notify(actor: Flynn.any) { expectation.fulfill() }
        wait(for: [expectation], timeout: 5)

        let entered = XCTestExpectation(description: "entered")
        Thread {
            group.enter()
            group.leave()
            entered.fulfill()
        }.start()
        wait(for: [entered], timeout: 5)
    }

    func testDispatchGroupNotifyIsAttributedToCaller() {
        let counter = Counter()
        counter.unsafeSuspend()

        let group = DispatchGroup()
        let notifyLine: UInt = #line + 1
        group.notify(actor: counter) { }

        XCTAssertEqual(waitForLive(1, #file, notifyLine), 1)
        XCTAssertFalse(Flynn.CallSites.top().contains { $0.callSite.contains("Flynn+Group.swift") })

        counter.unsafeResume()
        XCTAssertEqual(waitForLive(0, #file, notifyLine), 0)
    }

    private func noFlynnInternals(_ samples: [Flynn.CallSites.Sample]) -> Bool {
        return samples.contains { $0.callSite.contains("Extensions.swift") } == false
    }

    func testCollectionAsyncIsAttributedToCaller() {
        let receiver = Counter()
        receiver.unsafeSuspend()

        let gate = NSCondition()
        var release = false
        let done = XCTestExpectation(description: "done")

        // multiple-trailing-closure form must still bind each/done with the new parameters
        let callLine: UInt = #line + 1
        Array(0..<4).async(count: 2, receiver) { _, _ in
            gate.lock(); while !release { gate.wait() }; gate.unlock()
        } done: {
            done.fulfill()
        }

        // each worker is running an item, all attributed to the async() call
        let workers = min(2, Flynn.cores)
        XCTAssertEqual(waitForLive(workers, #file, callLine), workers)
        XCTAssertTrue(noFlynnInternals(Flynn.CallSites.top()))

        gate.lock(); release = true; gate.broadcast(); gate.unlock()

        // the done callback waits in the suspended receiver, still attributed to the call
        XCTAssertEqual(waitForLive(1, #file, callLine), 1)
        XCTAssertTrue(noFlynnInternals(Flynn.CallSites.top()))

        receiver.unsafeResume()
        wait(for: [done], timeout: 5)
        XCTAssertEqual(waitForLive(0, #file, callLine), 0)
    }

    func testCollectionSyncIsAttributedToCaller() {
        let callLine: UInt = #line + 1
        Array(0..<100).sync(count: 4) { _, _ in
            XCTAssertGreaterThan(self.live(#file, callLine), 0)
        }
        XCTAssertTrue(noFlynnInternals(Flynn.CallSites.top()))
        XCTAssertEqual(waitForLive(0, #file, callLine), 0)
    }

    func testCollectionAsyncOOBDoneIsAttributedToCaller() {
        let receiver = Counter()
        receiver.unsafeSuspend()
        let done = XCTestExpectation(description: "done")

        let callLine: UInt = #line + 1
        Array(0..<10).asyncOOB(count: 2, timeout: 0, receiver, each: { _, _ in }, done: { done.fulfill() })

        XCTAssertEqual(waitForLive(1, #file, callLine), 1)
        XCTAssertTrue(noFlynnInternals(Flynn.CallSites.top()))

        receiver.unsafeResume()
        wait(for: [done], timeout: 5)
        XCTAssertEqual(waitForLive(0, #file, callLine), 0)
    }
}
