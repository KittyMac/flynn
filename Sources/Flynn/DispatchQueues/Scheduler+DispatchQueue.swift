//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

#if !PLATFORM_SUPPORTS_PONYRT

public enum CoreAffinity: Int32 {
    case preferEfficiency = 0
    case preferPerformance = 1
    case onlyEfficiency = 2
    case onlyPerformance = 3
}

open class Scheduler {

    private var actors = Queue<Actor>()

    private let affinity: CoreAffinity
    private let uuid: String

    private lazy var thread = Thread(block: run)
    private var running: Bool

    init(_ affinity: CoreAffinity) {
        self.affinity = affinity
        self.uuid = UUID().uuidString

        running = true

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
            while let actor = actors.dequeue() {
                scalingSleep = 0
                if actor.unsafeRun() {
                    actors.enqueue(actor)
                }
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

#endif
