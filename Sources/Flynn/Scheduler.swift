//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

public enum CoreAffinity: Int {
    case preferEfficiency = 0
    case preferPerformance = 1
    case onlyEfficiency = 2
    case onlyPerformance = 3
}

open class Scheduler {

    private var actors = Queue<Actor>(128)

    private let index: Int
    private let affinity: CoreAffinity
    private let uuid: String

    private lazy var thread = Thread(block: run)
    private var running: Bool

    var count: Int {
        return actors.count
    }

    init(_ index: Int, _ affinity: CoreAffinity) {
        self.index = index
        self.affinity = affinity
        self.uuid = UUID().uuidString

        running = true

        if affinity == .onlyPerformance {
            thread.name = "Flynn #\(index) (P)"
            thread.qualityOfService = .userInitiated
        } else if affinity == .onlyEfficiency {
            thread.name = "Flynn #\(index) (E)"
            thread.qualityOfService = .utility
        } else {
            thread.name = "Flynn #\(index) (unknown)"
        }

        thread.start()
    }

    func schedule(_ actor: Actor) {
        //print("schedule \(actor)")
        actors.enqueue(actor)
    }

    func run() {
        var scalingSleep: UInt32 = 0

        #if TARGET_OS_IPHONE
            let scalingSleepDelta: UInt32 = 250
            let scalingSleepMin: UInt32 = 500
            let scalingSleepMax: UInt32 = 50000
        #else
            let scalingSleepDelta: UInt32 = 50
            let scalingSleepMin: UInt32 = 250
            let scalingSleepMax: UInt32 = 50000
        #endif

        while running {
            while let actor = actors.peek() {
                scalingSleep = 0
                if actor.unsafeRun() {
                    actors.enqueue(actor)
                }
                actors.dequeue()
            }

            if actors.isEmpty {
                scalingSleep += scalingSleepDelta
                if scalingSleep > scalingSleepMax {
                    scalingSleep = scalingSleepMax
                }
                if scalingSleep >= scalingSleepMin {
                    usleep(scalingSleep)
                }
            }
        }
    }

    public func join() {
        running = false

        // todo: use conditions
        while thread.isFinished == false {
            usleep(1000)
        }
    }

}
