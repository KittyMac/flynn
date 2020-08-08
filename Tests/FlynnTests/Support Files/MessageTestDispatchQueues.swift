//
//  FlynnTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import XCTest
@testable import Flynn

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

enum MessageTestDispatchQueues {
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
                    print("Late message, what???")
                }
            }
        }
        public func asyncPing(_ payload: UInt64) {
            queue.async {
                self._asyncPing()
            }
        }
    }
}
