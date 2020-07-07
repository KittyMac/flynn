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

    internal let index: Int
    internal let affinity: CoreAffinity
    internal let uuid: String
    internal var idle: Bool

    private lazy var thread = Thread(block: run)
    private var running: Bool

    private var waitingForWorkSemaphore = DispatchSemaphore(value: 0)

    var count: Int {
        return actors.count
    }

    init(_ index: Int, _ affinity: CoreAffinity) {
        self.index = index
        self.affinity = affinity
        self.uuid = UUID().uuidString

        running = true
        idle = false

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
        waitingForWorkSemaphore.signal()
    }

    func steal() -> Actor? {
        return actors.steal()
    }

    func run() {
        while running {
            while let actor = actors.dequeue() {

                // if i'm not allowed to run this actor due to core affinity, then we need
                // to rechedule this actor on a core which is allowed to run it.
                let actorAffinity = actor.unsafeCoreAffinity
                if (actorAffinity == .onlyEfficiency || actorAffinity == .onlyPerformance) &&
                    actorAffinity != affinity {
                    Flynn.schedule(actor, actor.unsafeCoreAffinity)
                    continue
                }

                while actor.unsafeRun() {
                    if let next = actors.peek() {
                        if next.unsafePriority >= actor.unsafePriority {
                            Flynn.schedule(actor, actor.unsafeCoreAffinity)
                            break
                        }
                    }

                    // If we prefer a different affinity, check to see if one of those schedulers
                    // is idle, if it is then we should reschedule to get on the right scheduler
                    if  (actorAffinity == .preferEfficiency && affinity == .onlyPerformance) ||
                        (actorAffinity == .preferPerformance && affinity == .onlyEfficiency) {
                        if Flynn.schedule(actor, actor.unsafeCoreAffinity, true) {
                            break
                        }
                    }
                }
            }

            if actors.isEmpty {
                idle = true
                waitingForWorkSemaphore.wait()
                idle = false
            }
        }
    }

    public func join() {
        running = false
        waitingForWorkSemaphore.signal()

        // todo: use conditions
        while thread.isFinished == false {
            usleep(1000)
        }
    }

}
