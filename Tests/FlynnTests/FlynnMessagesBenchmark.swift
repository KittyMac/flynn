//
//  FlynnTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// swiftlint:disable nesting
// swiftlint:disable function_body_length
// swiftlint:disable file_length

import XCTest

@testable import Flynn


class FlynnMessagesBenchmark: XCTestCase {

    override func setUp() {

    }

    override func tearDown() {

    }

    // MARK: - Pony

    // Results from running on 28-core, macOS Catalina:
    // 1596636590.588188000,1003048000,11014298
    // 1596636591.582950000,994710000,12227850
    // 1596636592.582895000,999905000,12716245
    // 1596636593.584596000,1001657000,12003966
    // 1596636594.581714000,997068000,12323487
    // 1596636595.584869000,1003117000,11290160
    // 1596636596.581278000,996360000,8608433
    // 1596636597.579241000,997917000,12666762
    // 1596636598.578671000,999381000,11073067
    // 1596636599.579306000,1000519000,10874956

    // MARK: - DISPATCH QUEUES

    func testMessagesTestDispatchQueues() {
        // Note: this test/benchmark was ported directly from the Pony language
        // benchmark message-ubench.  Comments kept in as-is.

        // Results from running on 28-core, macOS Catalina:
        // 2803.0952057160002,  5.1034000080107944e-05,  0
        // 2804.0982896650003,  1.000652960000025,  2052709
        // 2805.098551215,  1.0000033759997677,  1829365
        // 2806.0985887280003,  0.9997587360003308,  2523134
        // 2807.098880349,  1.0001698269998087,  1833887
        // 2808.099134869,  1.0000455949998468,  1836416
        // 2809.0993892670003,  1.000079960000221,  2037919
        // 2810.0996163080003,  1.0000864400003593,  1927992
        // 2811.0997210610003,  0.9998713879999741,  2162078
        // 2812.1000287670004,  1.0000930300002437,  1840786

        // A microbenchmark for measuring message passing rates in the Pony runtime.
        //
        // This microbenchmark executes a sequence of intervals.  During an interval,
        // 1 second long by default, the SyncLeader actor sends an initial
        // set of ping messages to a static set of Pinger actors.  When a Pinger
        // actor receives a ping() message, the Pinger will randomly choose
        // another Pinger to forward the ping() message.  This technique limits
        // the total number of messages "in flight" in the runtime to avoid
        // causing unnecessary memory consumption & overhead by the Pony runtime.
        //
        // This small program has several intended uses:
        //
        // * Demonstrate use of three types of actors in a Pony program: a timer,
        //   a SyncLeader, and many Pinger actors.
        //
        // * As a stress test for Pony runtime development, for example, finding
        //   deadlocks caused by experiments in the "Generalized runtime
        //   backpressure" work in pull request
        //   https://github.com/ponylang/ponyc/pull/2264
        //
        // * As a stress test for measuring message send & receive overhead for
        //   experiments in the "Add DTrace probes for all message push and pop
        //   operations" work in pull request
        //   https://github.com/ponylang/ponyc/pull/2295

        class SyncLeader {
            // The SyncLeader actor is responsible for creating all of the Pinger
            // worker actors and coordinating their activity during each report_pings
            // interval.
            //
            // Each interval includes the following activity:
            //
            // * SyncLeader uses the go() message to all Pinger workers that they
            //   are permitted to start work.
            // * SyncLeader uses ping() messages to trigger a cascade of ping()
            //   activity that will continue in a Pinger -> Pinger pattern.
            // * When the interval timer fires, SyncLeader uses the stop() message
            //   to tell all Pinger workers to stop sending messages and let any
            //   "in flight" messages to be received without creating new ping
            //   messages.
            // * The SyncLeader asks all Pinger workers to report the count of
            //   ping messages the Pinger had received during the work interval.
            private let initialPings: Int
            private var pingers: [Pinger] = []
            private var waitingFor: Int = 0
            private var partialCount: UInt64 = 0
            private var totalCount: UInt64 = 0
            private var currentT: TimeInterval = 0
            private var lastT: TimeInterval = 0
            private var done: Bool = false
            private var reportCount: Int = 0

            private var queue = DispatchQueue(label: "syncleader.serial.queue")

            init(_ numPingers: Int, _ initialPings: Int) {
                self.initialPings = initialPings

                // Create the desired number of Pinger actors and then send them
                // their initial ping() messages.
                for idx in 0..<numPingers {
                    pingers.append(Pinger(idx, self))
                }

                for pinger in pingers {
                    pinger.asyncSetNeighbors(pingers)
                }

                lastT = now()
            }

            private func now() -> TimeInterval {
                return ProcessInfo.processInfo.systemUptime
            }

            private func tellAllToGo() {
                // Tell all Pinger actors to start work.
                //
                // We do this in two phases: first go() then ping().  Otherwise we
                // have a race condition: if we send A.go() and A.ping(...), then
                // it is possible for A to send B.ping() before B receives a go().
                // If this race happens, then B will not include the ping in its
                // local message count, and B will also not forward the ping to
                // another actor: the message will be lost, and the system won't
                // perform the amount of work that we expected it to perform.

                for pinger in pingers {
                    pinger.asyncGo()
                }

                for _ in 0..<initialPings {
                    for pinger in pingers {
                        pinger.asyncPing(42)
                    }
                }
            }

            public func asyncTimerFired() {
                queue.async {
                    // The interval timer has fired.  Stop all Pingers and start
                    // waiting for confirmation that they have stopped.
                    self.reportCount += 1
                    self.done = self.reportCount >= 10

                    if self.done {
                        
                    }

                    self.currentT = self.now()
                    print("\(self.currentT)", terminator: "")

                    self.partialCount = 0
                    self.waitingFor = self.pingers.count

                    for pinger in self.pingers {
                        pinger.asyncStop()
                    }
                }
            }

            public func asyncReportStopped() {
                queue.async {
                    // Collect reports from Pingers that they have stopped working.
                    // If all have finished, then ask them to report their message
                    // received counts.
                    self.waitingFor -= 1
                    if self.waitingFor == 0 {
                        print(",", terminator: "")

                        self.waitingFor = self.pingers.count
                        for pinger in self.pingers {
                            pinger.asyncReport()
                        }
                    }
                }
            }

            public func asyncReportPings(_ idx: Int, _ count: UInt64) {
                queue.async {
                    // Collect message count reports.  If all have reported, then
                    // calculate the total message rate, then start the next work
                    // interval.
                    //
                    // We have separated the stop message and report message into
                    // a two-round synchronous protocol to ensure that ping messages
                    // from an earlier work interval are not counted in later
                    // intervals or cause memory consumption.
                    self.partialCount += count
                    self.waitingFor -= 1

                    if self.waitingFor == 0 {
                        let runNS = self.currentT - self.lastT
                        let rate = Double(self.partialCount) / runNS

                        print("  \(runNS),  \(Int(rate))")

                        if !self.done {
                            self.lastT = self.now()
                            self.waitingFor = self.pingers.count
                            self.totalCount += self.partialCount

                            self.tellAllToGo()
                        }
                    }
                }
            }
        }

        class Pinger {
            private var neighbors: [Pinger] = []
            private let idx: Int
            private let leader: SyncLeader
            private var go: Bool = false
            private var report: Bool = false
            private var count: UInt64 = 0
            private var neighborIdx: Int

            private var queue = DispatchQueue(label: "syncleader.serial.queue")

            init(_ idx: Int, _ leader: SyncLeader) {
                self.idx = idx
                self.neighborIdx = idx
                self.leader = leader
            }

            public func asyncSetNeighbors(_ pingers: [Pinger]) {
                queue.async {
                    self.neighbors = pingers
                }
            }

            public func asyncGo() {
                queue.async {
                    self.go = true
                    self.report = false
                    self.count = 0
                }
            }

            public func asyncStop() {
                queue.async {
                    self.go = false
                    self.leader.asyncReportStopped()
                }
            }

            public func asyncReport() {
                queue.async {
                    self.report = true
                    self.leader.asyncReportPings(self.idx, self.count)
                    self.count = 0
                }
            }

            private func _asyncPing() {
                if go {
                    count += 1
                    neighborIdx = (neighborIdx + 1) % neighbors.count
                    neighbors[neighborIdx].asyncPing(42)
                } else {
                    if report == true {
                        fatalError("Late message, what???")
                    }
                }
            }
            public func asyncPing(_ payload: UInt64) {
                queue.async {
                    self._asyncPing()
                }
            }

        }

        let numPingers = 8 // Number of intra-process Pony ping actors
        let reportInterval = 1.0 // print report every second
        let initialPings = 5

        let syncLeader = SyncLeader(numPingers, initialPings)

        for _ in 0..<10 {
            sleep(UInt32(reportInterval))
            syncLeader.asyncTimerFired()
        }
    }

    // MARK: - FLYNN

    func testMessagesTestFlynn() {
        // Note: this test/benchmark was ported directly from the Pony language
        // benchmark message-ubench.  Comments kept in as-is.

        // Results from running on 28-core, macOS Catalina:
        // 3830.2188045300004,  8.404000027439906e-05,  0
        // 3831.218828294,  0.999570735999896,  2293228
        // 3832.2188198480003,  0.9997923119999541,  2347845
        // 3833.2188276620004,  0.9998867030003566,  2315655
        // 3834.218842691,  0.9999017820000518,  2383554
        // 3835.218849716,  0.9998809269995945,  2358444
        // 3836.219106926,  1.0001419939999323,  2328586
        // 3837.218867331,  0.9996174090001659,  2388329
        // 3838.2188803490003,  0.9998824069998591,  2332060
        // 3839.218889304,  0.9998543140000038,  2347498

        // A microbenchmark for measuring message passing rates in the Pony runtime.
        //
        // This microbenchmark executes a sequence of intervals.  During an interval,
        // 1 second long by default, the SyncLeader actor sends an initial
        // set of ping messages to a static set of Pinger actors.  When a Pinger
        // actor receives a ping() message, the Pinger will randomly choose
        // another Pinger to forward the ping() message.  This technique limits
        // the total number of messages "in flight" in the runtime to avoid
        // causing unnecessary memory consumption & overhead by the Pony runtime.
        //
        // This small program has several intended uses:
        //
        // * Demonstrate use of three types of actors in a Pony program: a timer,
        //   a SyncLeader, and many Pinger actors.
        //
        // * As a stress test for Pony runtime development, for example, finding
        //   deadlocks caused by experiments in the "Generalized runtime
        //   backpressure" work in pull request
        //   https://github.com/ponylang/ponyc/pull/2264
        //
        // * As a stress test for measuring message send & receive overhead for
        //   experiments in the "Add DTrace probes for all message push and pop
        //   operations" work in pull request
        //   https://github.com/ponylang/ponyc/pull/2295

        class SyncLeader: Actor {
            /// The SyncLeader actor is responsible for creating all of the Pinger
            /// worker actors and coordinating their activity during each report_pings
            /// interval.
            ///
            /// Each interval includes the following activity:
            ///
            /// * SyncLeader uses the go() message to all Pinger workers that they
            ///   are permitted to start work.
            /// * SyncLeader uses ping() messages to trigger a cascade of ping()
            ///   activity that will continue in a Pinger -> Pinger pattern.
            /// * When the interval timer fires, SyncLeader uses the stop() message
            ///   to tell all Pinger workers to stop sending messages and let any
            ///   "in flight" messages to be received without creating new ping
            ///   messages.
            /// * The SyncLeader asks all Pinger workers to report the count of
            ///   ping messages the Pinger had received during the work interval.
            private let initialPings: Int
            private var pingers: [Pinger] = []
            private var waitingFor: Int = 0
            private var partialCount: UInt64 = 0
            private var totalCount: UInt64 = 0
            private var currentT: TimeInterval = 0
            private var lastT: TimeInterval = 0
            private var done: Bool = false
            private var reportCount: Int = 0

            init(_ numPingers: Int, _ initialPings: Int) {
                self.initialPings = initialPings

                super.init()

                // Create the desired number of Pinger actors and then send them
                // their initial ping() messages.
                for idx in 0..<numPingers {
                    pingers.append(Pinger(idx, self))
                }

                for pinger in pingers {
                    pinger.beSetNeighbors(pingers)
                }

                lastT = now()
            }

            private func now() -> TimeInterval {
                return ProcessInfo.processInfo.systemUptime
            }

            private func tellAllToGo() {
                // Tell all Pinger actors to start work.
                //
                // We do this in two phases: first go() then ping().  Otherwise we
                // have a race condition: if we send A.go() and A.ping(...), then
                // it is possible for A to send B.ping() before B receives a go().
                // If this race happens, then B will not include the ping in its
                // local message count, and B will also not forward the ping to
                // another actor: the message will be lost, and the system won't
                // perform the amount of work that we expected it to perform.

                for pinger in pingers {
                    pinger.beGo()
                }

                for _ in 0..<initialPings {
                    for pinger in pingers {
                        pinger.bePing(42)
                    }
                }
            }

            private func _beTimerFired() {
                // The interval timer has fired.  Stop all Pingers and start
                // waiting for confirmation that they have stopped.
                //let timer: Flynn.Timer? = args[x:0]

                self.reportCount += 1
                self.done = self.reportCount >= 10

                //if self.done {
                //    timer?.cancel()
                //}

                self.currentT = self.now()
                print("\(self.currentT)", terminator: "")

                self.partialCount = 0
                self.waitingFor = self.pingers.count

                for pinger in self.pingers {
                    pinger.beStop()
                }
            }
            public func beTimerFired() {
                unsafeSend(_beTimerFired)
            }

            private func _beReportStopped() {
                // Collect reports from Pingers that they have stopped working.
                // If all have finished, then ask them to report their message
                // received counts.
                self.waitingFor -= 1
                if self.waitingFor == 0 {
                    print(",", terminator: "")

                    self.waitingFor = self.pingers.count
                    for pinger in self.pingers {
                        pinger.beReport()
                    }
                }
            }
            public func beReportStopped() {
                unsafeSend(_beReportStopped)
            }

            private func _beReportPings(_ idx: Int, _ count: UInt64) {
                // Collect message count reports.  If all have reported, then
                // calculate the total message rate, then start the next work
                // interval.
                //
                // We have separated the stop message and report message into
                // a two-round synchronous protocol to ensure that ping messages
                // from an earlier work interval are not counted in later
                // intervals or cause memory consumption.

                self.partialCount += count
                self.waitingFor -= 1

                if self.waitingFor == 0 {
                    let runNS = self.currentT - self.lastT
                    let rate = Double(self.partialCount) / runNS

                    print("  \(runNS),  \(Int(rate))")

                    if !self.done {
                        self.lastT = self.now()
                        self.waitingFor = self.pingers.count
                        self.totalCount += self.partialCount

                        self.tellAllToGo()
                    }
                }
            }
            public func beReportPings(_ idx: Int, _ count: UInt64) {
                unsafeSend { [unowned self] in
                    self._beReportPings(idx, count)
                }
            }
        }

        class Pinger: Actor {
            private var neighbors: [Pinger] = []
            private let idx: Int
            private let leader: SyncLeader
            private var go: Bool = false
            private var report: Bool = false
            private var count: UInt64 = 0
            private var neighborIdx: Int
            
            private var neighbor: Pinger?

            init(_ idx: Int, _ leader: SyncLeader) {
                self.idx = idx
                self.neighborIdx = idx
                self.leader = leader
            }

            private func _beSetNeighbors(_ neighbors: [Pinger]) {
                self.neighbors = neighbors
                self.neighbor = self.neighbors[(self.neighborIdx + 1) % self.neighbors.count]
            }
            public func beSetNeighbors(_ neighbors: [Pinger]) {
                unsafeSend { [unowned self] in
                    self._beSetNeighbors(neighbors)
                }
            }

            private func _beGo() {
                self.go = true
                self.report = false
            }
            public func beGo() {
                unsafeSend(_beGo)
            }

            private func _beStop() {
                self.go = false
                self.leader.beReportStopped()
            }
            public func beStop() {
                unsafeSend(_beStop)
            }

            private func _beReport() {
                self.report = true
                self.leader.beReportPings(self.idx, self.count)
                self.count = 0
            }
            public func beReport() {
                unsafeSend(_beReport)
            }

           
            private func _bePing(_ payload: Int) {
                if go {
                    count += 1
                    neighbor?.bePing(42)
                    //neighborIdx = (neighborIdx &+ 1) % neighbors.count
                    //neighbors[neighborIdx].bePing(42)
                } else {
                    if report == true {
                        fatalError("Late message, what???")
                    }
                }
            }
            public func bePing(_ payload: Int) {
                unsafeSend({ [unowned self] in
                    self._bePing(payload)
                })
            }

        }

        Flynn.startup()

        let numPingers = 512 // Number of intra-process Pony ping actors
        let reportInterval = 1 // print report every second
        let initialPings = 5

        let syncLeader = SyncLeader(numPingers, initialPings)

        for _ in 0..<10 {
            sleep(UInt32(reportInterval))
            syncLeader.beTimerFired()
        }

        //Flynn.Timer(timeInterval: reportInterval, repeats: true, syncLeader.beTimerFired, [])

        Flynn.shutdown()
    }

}

