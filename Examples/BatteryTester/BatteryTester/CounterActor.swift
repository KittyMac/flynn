//
//  ViewController.swift
//  BatteryTester
//
//  Created by Rocco Bowling on 6/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import Flynn

class Counter: Actor {
    public var unsafeCount: Int = 0
    public var unsafeSleepAmount: UInt32 = 0

    private var done: Bool = false
    private let batchCount: Int  = 100000

    init(_ sleepAmount: UInt32, _ qos: Int) {
        super.init()

        if let qos = CoreAffinity(rawValue: qos) {
            unsafeCoreAffinity = qos
        }

        unsafeSleepAmount = sleepAmount

        beCount()
    }

    private func count() {
        for _ in 0..<batchCount {
            unsafeCount += 1
        }
        if done == false {
            if unsafeSleepAmount > 0 {
                usleep(unsafeSleepAmount)
            }
            self.beCount()
        }
    }

    lazy var beCount = Behavior(self) { [unowned self] (_ : BehaviorArgs) in
        self.count()
    }

    lazy var beStop = Behavior(self) { [unowned self] (_ : BehaviorArgs) in
        self.done = true
    }

    lazy var beSetCoreAffinity = Behavior(self) { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter Int - core affinity value
        if let qos = CoreAffinity(rawValue: args[x:0]) {
            self.unsafeCoreAffinity = qos
        }
    }
}
