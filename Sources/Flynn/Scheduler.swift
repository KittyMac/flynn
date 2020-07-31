//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// swiftlint:disable line_length

import Foundation

public enum CoreAffinity: Int {
    case preferEfficiency = 0
    case preferPerformance = 1
    case onlyEfficiency = 2
    case onlyPerformance = 3
    case none = 99
}

open class Scheduler {

    private var actors = Queue<Actor>(128, true, true, false)

    internal let index: Int
    internal let affinity: CoreAffinity
    internal let uuid: String
    internal var idle: Bool

    internal var timeIdle: TimeInterval = 0
    internal var timeActive: TimeInterval = 0
    internal var actorsRun: Int64 = 0

    // Thread(block: run) is preferable, but requires 10.12. Can't use selectors on linux
    // (no objc) so we use the block version on linux and the selector version everywhere
    // else. We can switch to the all blocks version for everyone in the future.
#if os(Linux)
    private lazy var thread = Thread(block: run)
#else
    private lazy var thread = Thread(target: self, selector: #selector(run), object: nil)
#endif

    private var running: Bool

    private var waitingForWorkSemaphore = DispatchSemaphore(value: 0)

    var count: Int {
        if idle {
            return actors.count
        }
        return actors.count + 1
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
        if !running {
            Flynn.schedule(actor, actor.unsafeCoreAffinity)
            return
        }

        actors.enqueue(actor)

        if idle {
            waitingForWorkSemaphore.signal()
        }
    }
    
    func wake() {
        waitingForWorkSemaphore.signal()
    }

    private func runInternal() {
#if DEBUG
        var timeMark = ProcessInfo.processInfo.systemUptime
#endif

        while let actor = actors.dequeue() {
            // if we're not allowed on this scheduler due to core affinity, then
            // we need to reschedule this actor on one which can run it
            var actorAffinity = actor.unsafeCoreAffinity
            if (actorAffinity == .onlyEfficiency || actorAffinity == .onlyPerformance) &&
                actorAffinity != affinity {
                Flynn.schedule(actor, actor.unsafeCoreAffinity)
                //print("affinity bounce, 1a for \(actor) on \(self.index) with \(actorAffinity) and \(affinity)")
                continue
            }

            actorsRun += 1
            while actor.unsafeRun() {
                actorAffinity = actor.unsafeCoreAffinity

                if let next = actors.peek() {
                    if next.unsafePriority >= actor.unsafePriority {
                        Flynn.schedule(actor, actor.unsafeCoreAffinity)
                        break
                    } else {
                        // if we're going to keep running we need to make sure the people
                        // behind us don't starve.  Dequeue one and reschedule it somewhere
                        // else
                        if let next = actors.dequeue() {
                            Flynn.scheduleOtherThan(self, next, next.unsafeCoreAffinity)
                            //print("priority starvation (keeping \(actor), bouncing \(next)")
                        }
                    }
                }

                // Before we can just re-run the same actor, we need to ensure the
                // core affinities, which might have changed, are still good
                if (actorAffinity == .onlyEfficiency || actorAffinity == .onlyPerformance) &&
                    actorAffinity != affinity {
                    Flynn.schedule(actor, actor.unsafeCoreAffinity)
                    //print("affinity bounce, 1b for \(actor) on \(self.index) with \(actorAffinity) and \(affinity)")
                    break
                }
                if  (actorAffinity == .preferEfficiency && affinity == .onlyPerformance) ||
                    (actorAffinity == .preferPerformance && affinity == .onlyEfficiency) {
                    if Flynn.scheduleIfIdle(actor, actor.unsafeCoreAffinity) {
                        //print("affinity bounce, 2 for \(actor) on \(self.index) with \(actorAffinity) and \(affinity)")
                        break
                    }
                }
            }
        }

#if DEBUG
        timeActive += ProcessInfo.processInfo.systemUptime - timeMark
#endif

        if actors.isEmpty {
            idle = true
#if DEBUG
            timeMark = ProcessInfo.processInfo.systemUptime
#endif
            waitingForWorkSemaphore.wait()
#if DEBUG
            timeIdle += ProcessInfo.processInfo.systemUptime - timeMark
#endif

            idle = false
        }
    }

    @objc func run() {
        while running {
#if os(Linux)
            runInternal()
#else
            autoreleasepool {
                runInternal()
            }
#endif
        }
    }

    public func join() {
        running = false
        waitingForWorkSemaphore.signal()
        while thread.isFinished == false {
            usleep(1000)
        }
    }

}
