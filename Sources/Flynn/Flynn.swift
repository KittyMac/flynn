//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

open class Flynn {

    // MARK: - User Configurable Settings
#if DEBUG
    public static var defaultCheckForUnsafeArguments: Bool = true
#else
    public static var defaultCheckForUnsafeArguments: Bool = false
#endif

#if os(iOS)
    public static var defaultActorAffinity: CoreAffinity = .preferEfficiency
#else
    public static var defaultActorAffinity: CoreAffinity = .none
#endif

    private static var schedulers: [Scheduler] = []
    private static var schedulerIdx: Int = 0
    private static var running = AtomicContidion()
    private static var device = Device()

    public class func startup() {
        running.checkInactive {
            for _ in 0..<device.eCores {
                schedulers.append(Scheduler(schedulers.count, .onlyEfficiency))
            }
            for _ in 0..<device.pCores {
                schedulers.append(Scheduler(schedulers.count, .onlyPerformance))
            }
        }
    }

    public class func shutdown() {
        running.checkActive {
            for scheduler in schedulers {
                scheduler.join()
            }
            schedulers.removeAll()
        }
    }

    public static var cores: Int {
        return device.cores
    }

    private static var lastSchedulerIdx: Int = 0
    @inline(__always)
    public static func schedule(_ actor: Actor, _ coreAffinity: CoreAffinity) {
        lastSchedulerIdx = (lastSchedulerIdx + 1) % schedulers.count
        schedulers[lastSchedulerIdx].schedule(actor)
    }

    @inline(__always)
    public static func scheduleOtherThan(_ notThisOne: Scheduler, _ actor: Actor, _ coreAffinity: CoreAffinity) {
        while true {
            lastSchedulerIdx = (lastSchedulerIdx + 1) % schedulers.count
            if lastSchedulerIdx != notThisOne.index {
                schedulers[lastSchedulerIdx].schedule(actor)
                return
            }
        }
    }

    @inline(__always)
    @discardableResult
    public static func scheduleIfIdle(_ actor: Actor, _ coreAffinity: CoreAffinity) -> Bool {
        var matchAffinity: CoreAffinity = .onlyEfficiency
        if actor.unsafeCoreAffinity == .onlyPerformance || actor.unsafeCoreAffinity == .preferPerformance {
            matchAffinity = .onlyPerformance
        }

        // we want to find an idle scheduler which matches our core affinity.
        // If one doesn't exist, then we should return false and not schedule the actor
        for scheduler in schedulers {
            if scheduler.idle && scheduler.affinity == matchAffinity {
                scheduler.schedule(actor)
                return true
            }
        }
        return false
    }
}
