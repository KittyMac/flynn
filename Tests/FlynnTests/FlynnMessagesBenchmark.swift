//
//  FlynnTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// swiftlint:disable nesting
// swiftlint:disable function_body_length

import XCTest

@testable import Flynn

class FlynnMessagesBenchmark: XCTestCase {

    override func setUp() {

    }

    override func tearDown() {

    }

    func testMessagesTest() {
        // Note: this test/benchmark was ported directly from the Pony language
        // benchmark message-ubench.  Comments kept in as-is.

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

            lazy var beTimerFired = Behavior(self) { [unowned self] (args: BehaviorArgs) in
                // flynnlint:parameter Timer? - the timer who called this behavior, if it exists

                // The interval timer has fired.  Stop all Pingers and start
                // waiting for confirmation that they have stopped.
                let timer: Flynn.Timer? = args[x:0]

                self.reportCount += 1
                self.done = self.reportCount >= 10

                if self.done {
                    timer?.cancel()
                }

                self.currentT = self.now()
                print("\(self.currentT)", terminator: "")

                self.partialCount = 0
                self.waitingFor = self.pingers.count

                for pinger in self.pingers {
                    pinger.beStop()
                }
            }

            lazy var beReportStopped = Behavior(self) { [unowned self] (_: BehaviorArgs) in
                // flynnlint:parameter Int - the idx of the pinger who stopped

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

            lazy var beReportPings = Behavior(self) { [unowned self] (args: BehaviorArgs) in
                // flynnlint:parameter Int - the idx of the pinger who stopped
                // flynnlint:parameter UInt64 - the number of pings performed

                // Collect message count reports.  If all have reported, then
                // calculate the total message rate, then start the next work
                // interval.
                //
                // We have separated the stop message and report message into
                // a two-round synchronous protocol to ensure that ping messages
                // from an earlier work interval are not counted in later
                // intervals or cause memory consumption.
                let idx: Int = args[x:0]
                let count: UInt64 = args[x:1]

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

        class Pinger: Actor {
            private var neighbors: [Pinger] = []
            private let idx: Int
            private let leader: SyncLeader
            private var go: Bool = false
            private var report: Bool = false
            private var count: UInt64 = 0
            private var neighborIdx: Int

            init(_ idx: Int, _ leader: SyncLeader) {
                self.idx = idx
                self.neighborIdx = idx
                self.leader = leader
            }

            private func sendPings() {
                neighborIdx = (neighborIdx + 1) % neighbors.count
                neighbors[neighborIdx].bePing(42)

                // Note: we're currently 15x slower than Pony :(
                //15,281,896
            }

            lazy var beSetNeighbors = Behavior(self) { [unowned self] (args: BehaviorArgs) in
                // flynnlint:parameter [Pinger] - array of Pingers
                self.neighbors = args[x:0]
            }

            lazy var beGo = Behavior(self) { [unowned self] (_: BehaviorArgs) in
                self.go = true
                self.report = false
                self.count = 0
            }

            lazy var beStop = Behavior(self) { [unowned self] (_: BehaviorArgs) in
                self.go = false
                self.leader.beReportStopped()
            }

            lazy var beReport = Behavior(self) { [unowned self] (_: BehaviorArgs) in
                self.report = true
                self.leader.beReportPings(self.idx, self.count)
                self.count = 0
            }

            lazy var bePing = Behavior(self) { [unowned self] (args: BehaviorArgs) in
                // flynnlint:parameter Int - the answer to everything
                let payload: Int = args[x:0]

                if self.go {
                    self.count += 1
                    self.sendPings()
                } else {
                    if self.report == true {
                        fatalError("Late message, what???")
                    }
                }
            }

        }

        Flynn.startup()

        let numPingers = 8 // Number of intra-process Pony ping actors
        let reportInterval = 1.0 // print report every second
        let initialPings = 5

        let syncLeader = SyncLeader(numPingers, initialPings)

        syncLeader.beTimerFired(nil)

        Flynn.Timer(timeInterval: reportInterval, repeats: true, syncLeader.beTimerFired, [])

        Flynn.shutdown()
    }

}
