// flynn:ignore Access Level Violation: Unsafe variables should not be used
// flynn:ignore Weak Timer Violation: Flynn.Timer callbacks should use [weak self]

import XCTest

import Flynn

// MARK: - actors under test

class TestIOActor: IOActor {
    private var processed: Int = 0
    private var order: [Int] = []

    // Safe to read only once the runtime is down and nothing is running.
    public var unsafeProcessed: Int {
        return processed
    }

    internal func _beThreadName(_ returnCallback: @escaping (String) -> ()) {
        returnCallback(Thread.current.name ?? "")
    }

    // Blocks the actor's thread, which is the whole point of an IOActor.
    internal func _beBlock(_ milliseconds: Int) {
        if milliseconds > 0 {
            Flynn.usleep(UInt64(milliseconds) * 1000)
        }
        processed += 1
    }

    internal func _beRecord(_ index: Int) {
        order.append(index)
        processed += 1
    }

    internal func _beResults(_ returnCallback: @escaping (Int, [Int]) -> ()) {
        returnCallback(processed, order)
    }

    internal func _beWork(_ milliseconds: Int, _ returnCallback: @escaping (Int) -> ()) {
        if milliseconds > 0 {
            Flynn.usleep(UInt64(milliseconds) * 1000)
        }
        processed += 1
        returnCallback(processed)
    }

    internal func _beFirst(_ returnCallback: @escaping () -> ()) {
        order.append(1)
        returnCallback()
    }
    internal func _beSecond(_ returnCallback: @escaping () -> ()) {
        order.append(2)
        returnCallback()
    }
    internal func _beThird(_ returnCallback: @escaping ([Int]) -> ()) {
        order.append(3)
        returnCallback(order)
    }

    // Chained from inside a behavior, which is the idiom the rest of the test
    // suite uses for then/do.
    internal func _beChain(_ returnCallback: @escaping ([Int]) -> ()) {
        self.beFirst(self) {
        }.then().doSecond(self) {
        }.then().doThird(self) { recorded in
            returnCallback(recorded)
        }
    }

    @available(iOS 13.0, *)
    @available(macOS 10.15, *)
    internal func _beSuspendAndResume(_ returnCallback: @escaping (String, String) -> ()) {
        let before = Thread.current.name ?? ""
        safeTask { resume in
            try? await Task.sleep(nanoseconds: 100_000_000)
            resume()
        }
        // Runs once the actor has been resumed, on whichever thread resumed it.
        unsafeSend { _ in
            returnCallback(before, Thread.current.name ?? "")
        }
    }
}

class TestBlockingActor: Actor {
    internal func _beBlock(_ milliseconds: Int) {
        if milliseconds > 0 {
            Flynn.usleep(UInt64(milliseconds) * 1000)
        }
    }
    internal func _beThreadName(_ returnCallback: @escaping (String) -> ()) {
        returnCallback(Thread.current.name ?? "")
    }
}

// Sends to itself as fast as it can. How many times it manages to run while
// something else is blocking is a direct measure of scheduler availability.
class TestPinger: Actor {
    private var count: Int = 0
    private var running: Bool = false

    internal func _beStart() {
        running = true
        unsafeSend { _ in self._beTick() }
    }
    internal func _beTick() {
        guard running else { return }
        count += 1
        unsafeSend { _ in self._beTick() }
    }
    internal func _beStop(_ returnCallback: @escaping (Int) -> ()) {
        running = false
        returnCallback(count)
    }
}

class TestIOTimerTarget: IOActor, Timerable {
    private var fired: Int = 0

    internal func _beTimerFired(_ timer: Flynn.Timer, _ args: TimerArgs) {
        fired += 1
    }
    internal func _beFired(_ returnCallback: @escaping (Int) -> ()) {
        returnCallback(fired)
    }
}

// MARK: - tests

class IOActorTests: XCTestCase {

    override func setUp() {
        Flynn.startup()
    }

    override func tearDown() {
        Flynn.shutdown()
    }

    // Enough blocking actors to oversubscribe the schedulers on any machine.
    private var blockerCount: Int {
        return max(8, Flynn.cores + 4)
    }

    private func waitUntil(_ timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let start = Date()
        while abs(start.timeIntervalSinceNow) < timeout {
            if condition() { return true }
            Flynn.usleep(2000)
        }
        return condition()
    }

    func testRunsOnItsOwnThread() {
        let expectation = XCTestExpectation(description: #function)

        let io = TestIOActor()
        var ioThread = ""
        var schedulerThread = ""

        XCTAssertEqual(1, Flynn.ioActors)

        let normal = TestBlockingActor()
        normal.beThreadName(Flynn.any) { name in
            schedulerThread = name
            io.beThreadName(Flynn.any) { name in
                ioThread = name
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10.0)

        // Thread names are best effort: Foundation does not surface one on every
        // platform. Only assert on them when there is something to assert on.
        if ioThread.isEmpty == false && schedulerThread.isEmpty == false {
            XCTAssertNotEqual(ioThread, schedulerThread)
            XCTAssertTrue(ioThread.contains("TestIOActor"))
        }
    }

    // The reason IOActor exists: blocking one must not cost a scheduler thread.
    func testBlockingDoesNotStarveTheSchedulers() {
        let count = blockerCount

        // IOActors first.
        let ioExpectation = XCTestExpectation(description: "\(#function) io")
        ioExpectation.expectedFulfillmentCount = count * 4

        let ios = (0..<count).map { _ in TestIOActor() }
        let ioPinger = TestPinger()
        ioPinger.beStart()

        var start = Date()
        for io in ios {
            for _ in 0..<4 {
                io.beWork(200, Flynn.any) { _ in ioExpectation.fulfill() }
            }
        }
        wait(for: [ioExpectation], timeout: 60.0)
        let ioElapsed = abs(start.timeIntervalSinceNow)

        let ioPingExpectation = XCTestExpectation(description: "\(#function) io pings")
        var ioPings = 0
        ioPinger.beStop(Flynn.any) { count in
            ioPings = count
            ioPingExpectation.fulfill()
        }
        wait(for: [ioPingExpectation], timeout: 10.0)

        // The same work on ordinary actors, for contrast.
        let actorExpectation = XCTestExpectation(description: "\(#function) actors")
        actorExpectation.expectedFulfillmentCount = count * 4

        let actors = (0..<count).map { _ in TestBlockingActor() }
        let actorPinger = TestPinger()
        actorPinger.beStart()

        start = Date()
        for actor in actors {
            for _ in 0..<4 {
                actor.beBlock(200).unsafeSend { _ in actorExpectation.fulfill() }
            }
        }
        wait(for: [actorExpectation], timeout: 120.0)
        let actorElapsed = abs(start.timeIntervalSinceNow)

        let actorPingExpectation = XCTestExpectation(description: "\(#function) actor pings")
        var actorPings = 0
        actorPinger.beStop(Flynn.any) { count in
            actorPings = count
            actorPingExpectation.fulfill()
        }
        wait(for: [actorPingExpectation], timeout: 10.0)

        print("IOActors: \(ioElapsed)s, pinger ran \(ioPings) times")
        print("Actors:   \(actorElapsed)s, pinger ran \(actorPings) times")

        // Each IOActor has a thread of its own, so four 200ms messages each is
        // ~0.8s however many of them there are.
        XCTAssertLessThan(ioElapsed, 5.0)

        // Ordinary actors have to share the schedulers, so the same work takes
        // longer and leaves nothing for anybody else to run on.
        XCTAssertLessThan(ioElapsed, actorElapsed)
        XCTAssertGreaterThan(ioPings, actorPings)
    }

    func testMessagesAreProcessedInOrder() {
        let expectation = XCTestExpectation(description: #function)

        let io = TestIOActor()
        for index in 0..<500 {
            io.beRecord(index)
        }

        var processed = 0
        var order: [Int] = []
        io.beResults(Flynn.any) { count, recorded in
            processed = count
            order = recorded
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 30.0)

        XCTAssertEqual(500, processed)
        XCTAssertEqual(Array(0..<500), order)
    }

    // Work sits in the actor's own message queue, so the queue depth is real and
    // unsafeWait() is real backpressure -- which is exactly what is lost when a
    // behavior hands its work off to an OperationQueue instead.
    func testQueueAccountingAndBackpressure() {
        let expectation = XCTestExpectation(description: #function)

        let io = TestIOActor()
        for _ in 0..<20 {
            io.beBlock(20)
        }

        XCTAssertGreaterThan(io.unsafeMessagesCount, 1)

        let start = Date()
        io.unsafeWait(0)
        let elapsed = abs(start.timeIntervalSinceNow)

        XCTAssertEqual(0, io.unsafeMessagesCount)
        XCTAssertGreaterThan(elapsed, 0.2)

        var processed = 0
        io.beResults(Flynn.any) { count, _ in
            processed = count
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        XCTAssertEqual(20, processed)
    }

    func testThenDo() {
        let expectation = XCTestExpectation(description: #function)

        let io = TestIOActor()
        var order: [Int] = []

        io.beChain(Flynn.any) { recorded in
            order = recorded
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)

        XCTAssertEqual([1, 2, 3], order)
    }

    func testSafeTaskSuspendAndResume() {
        guard #available(macOS 10.15, iOS 13.0, *) else { return }

        let expectation = XCTestExpectation(description: #function)

        let io = TestIOActor()
        var before = ""
        var after = ""

        io.beSuspendAndResume(Flynn.any) { threadBefore, threadAfter in
            before = threadBefore
            after = threadAfter
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 30.0)

        // A resumed IOActor goes back onto its own thread, not a scheduler.
        if before.isEmpty == false || after.isEmpty == false {
            XCTAssertEqual(before, after)
        }
    }

    func testTimerTargetingAnIOActor() {
        let expectation = XCTestExpectation(description: #function)

        let target = TestIOTimerTarget()
        let timer = Flynn.Timer(timeInterval: 0.05, repeats: true, target)

        Flynn.usleep(400_000)
        timer.cancel()

        var fired = 0
        target.beFired(Flynn.any) { count in
            fired = count
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        XCTAssertGreaterThanOrEqual(fired, 3)
    }

    // A dedicated thread lives and dies with its actor.
    func testThreadsAreReclaimed() {
        XCTAssertEqual(0, Flynn.ioActors)

        for _ in 0..<50 {
            let io = TestIOActor()
            io.beBlock(0)
            io.unsafeWait(0)
        }

        XCTAssertTrue(waitUntil(30.0) { Flynn.ioActors == 0 })
    }

    func testCancelReleasesTheThread() {
        let io = TestIOActor()
        io.beBlock(50)
        io.unsafeCancel()

        XCTAssertTrue(waitUntil(30.0) { Flynn.ioActors == 0 })
    }

    // Shutdown has to wait for a dedicated thread's in-flight work; the
    // schedulers being idle is not enough on its own.
    func testShutdownDrainsInFlightWork() {
        let io = TestIOActor()
        for _ in 0..<5 {
            io.beBlock(100)
        }

        Flynn.shutdown()

        // Nothing is running now, so read the actor's state directly: asking it
        // through a behavior would need the runtime we just shut down.
        XCTAssertEqual(5, io.unsafeProcessed)
    }
}
