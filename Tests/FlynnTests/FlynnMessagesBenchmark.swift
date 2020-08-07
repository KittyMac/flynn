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

    // Results from running on 28-core, macOS Catalina, 512 pingers:
    // 1596741470.763385000,999048000,39486738
    // 1596741471.762658000,998260000,39707495
    // 1596741472.763004000,999382000,40067748
    // 1596741473.761554000,997578000,39637181
    // 1596741474.760698000,998178000,39849693
    // 1596741475.759487000,997841000,39532955
    // 1596741476.758133000,997708000,39948868
    // 1596741477.762267000,1003116000,39840914
    // 1596741478.757745000,994517000,39574160
    // 1596741479.760346000,1001635000,39693255
    // 1596741480.756346000,995154000,40074038

    // MARK: - DISPATCH QUEUES

    func testMessagesTestDispatchQueues() {
        // Note: this test/benchmark was ported directly from the Pony language
        // benchmark message-ubench.  Comments kept in as-is.

        // Results from running on 28-core, macOS Catalina, 512 pingers:
        // NOTE: Dispatch Queues really don't like 512 pingers and I haven't had time to
        // figure out why.  Including the output for reference.
        // 56008.35949495601,  1.001320259005297,  0
        // 56011.28257235300456011.42580318656011.428050639006,,  3.0623611960036214,  13986
        //   -0.006396996999683324,  -56107264
        // 56016.25465351200556016.4842601020156016.48657957356016.48854166300656016.490602864,,,,  2.9133747209998546,  22456

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
            private var reportCount: Int = 0
            private var done: Bool = false

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

            public func asyncTimerFired(_ done: Bool) {
                queue.async {
                    // The interval timer has fired.  Stop all Pingers and start
                    // waiting for confirmation that they have stopped.
                    self.done = done
                    
                    self.reportCount += 1

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

        let numPingers = 512 // Number of intra-process Pony ping actors
        let reportInterval = 1.0 // print report every second
        let initialPings = 5

        let syncLeader = SyncLeader(numPingers, initialPings)

        for _ in 0..<10 {
            sleep(UInt32(reportInterval))
            syncLeader.asyncTimerFired(false)
        }
        syncLeader.asyncTimerFired(true)
    }

    // MARK: - FLYNN

    func testMessagesTestFlynn() {
        // Note: this test/benchmark was ported directly from the Pony language
        // benchmark message-ubench.  Comments kept in as-is.

        // Results from running on 28-core, macOS Catalina, 512 pingers:
        // 9984.535411017001,  0.9979306630011706,  29230808
        // 9985.540364971,  1.0028819920007663,  29269366
        // 9986.544228205,  1.0013275140008773,  29429371
        // 9987.544452796,  0.9978043720002461,  29784492
        // 9988.544668666,  0.9980040519985778,  29265244
        // 9989.545868362,  0.9988699859986809,  29007760
        // 9990.546877921,  0.9989349309998943,  29250099
        // 9991.546983637001,  0.9978452790001029,  29677932
        // 9992.547778818001,  0.9986258280005131,  29159357
        // 9993.547844452001,  0.9980227110008855,  29769889
        // 9994.552421620001,  1.002462877000653,  29227430
        // 9995.552889342001,  0.9982467350000661,  29145377

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
            private var reportCount: Int = 0
            private var done: Bool = false

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

            private func _beTimerFired(_ done: Bool) {
                // The interval timer has fired.  Stop all Pingers and start
                // waiting for confirmation that they have stopped.
                self.done = done
                self.reportCount += 1

                self.currentT = self.now()
                print("\(self.currentT)", terminator: "")

                if !done {
                    self.partialCount = 0
                    self.waitingFor = self.pingers.count

                    for pinger in self.pingers {
                        pinger.beStop()
                    }
                }
            }
            public func beTimerFired(_ done: Bool) {
                unsafeSend {
                    self._beTimerFired(done)
                }
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
                unsafeSend {
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
                unsafeSend {
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
                unsafeSend {
                    self._bePing(payload)
                }
            }

        }

        Flynn.startup()

        let numPingers = 512 // Number of intra-process Pony ping actors
        let reportInterval = 1 // print report every second
        let initialPings = 5

        let syncLeader = SyncLeader(numPingers, initialPings)

        for _ in 0..<10 {
            sleep(UInt32(reportInterval))
            syncLeader.beTimerFired(false)
        }
        syncLeader.beTimerFired(true)

        //Flynn.Timer(timeInterval: reportInterval, repeats: true, syncLeader.beTimerFired, [])

        Flynn.shutdown()
    }

}
