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
        let numPingers = 512 // Number of intra-process Pony ping actors
        let reportInterval = 1.0 // print report every second
        let initialPings = 5

        let syncLeader = MessageTestDispatchQueues.SyncLeader(numPingers, initialPings)

        for _ in 0..<10 {
            sleep(UInt32(reportInterval))
            syncLeader.asyncTimerFired(false)
        }
        syncLeader.asyncTimerFired(true)
    }

    // MARK: - FLYNN

    func testMessagesTestFlynn() {
        Flynn.startup()

        let numPingers = 512 // Number of intra-process Pony ping actors
        let reportInterval = 1 // print report every second
        let initialPings = 5

        let syncLeader = MessageTestFlynn.SyncLeader(numPingers, initialPings)

        for _ in 0..<10 {
            sleep(UInt32(reportInterval))
            syncLeader.beTimerFired(false)
        }
        syncLeader.beTimerFired(true)

        //Flynn.Timer(timeInterval: reportInterval, repeats: true, syncLeader.beTimerFired, [])

        Flynn.shutdown()
    }

}
