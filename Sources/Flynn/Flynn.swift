//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

open class Flynn {
#if DEBUG
    public static var checkForUnsafeArguments: Bool = true
#else
    public static var checkForUnsafeArguments: Bool = false
#endif

    private static var schedulers: [Scheduler] = []
    private static var schedulerIdx: Int = 0
    private static var running = AtomicContidion()
    private static var device = Device()

    public class func startup() {
        running.checkInactive {
            for idx in 0..<device.eCores {
                schedulers.append(Scheduler(idx, .onlyEfficiency))
            }
            for idx in 0..<device.pCores {
                schedulers.append(Scheduler(idx, .onlyPerformance))
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

    @inline(__always)
    private static func minimumSchedulerWithStride(_ stride: StrideTo<Int>, _ onlyIfIdle: Bool) -> Scheduler? {
        var minIdx = 0
        var minCount = 999999

        var maxIdx = 0
        var maxCount = 0

        for idx in stride {
            if schedulers[idx].idle {
                return schedulers[idx]
            }
            let count = schedulers[idx].count
            if count < minCount {
                minCount = count
                minIdx = idx
            }
            if count > maxCount {
                maxCount = count
                maxIdx = idx
            }
        }

        if onlyIfIdle && schedulers[maxIdx].idle == true {
            return nil
        }

        if maxCount > 1 {
            if let actor = schedulers[maxIdx].steal() {
                Flynn.schedule(actor, actor.unsafeCoreAffinity)
            }
        }

        return schedulers[minIdx]
    }

    private static var lastSchedulerIdx: Int = 0
    @discardableResult
    public static func schedule(_ actor: Actor, _ coreAffinity: CoreAffinity, _ onlyIfIdle: Bool = false) -> Bool {

        lastSchedulerIdx = (lastSchedulerIdx + 1) % schedulers.count
        schedulers[lastSchedulerIdx].schedule(actor)
        return true
        /*
        var scheduler: Scheduler?

        if coreAffinity == .onlyEfficiency {
            scheduler = minimumSchedulerWithStride( stride(from: 0, to: device.eCores, by: 1), onlyIfIdle )
        } else if coreAffinity == .onlyPerformance {
            scheduler = minimumSchedulerWithStride( stride(from: device.eCores, to: device.cores, by: 1), onlyIfIdle )
        } else if coreAffinity == .preferPerformance {
            scheduler = minimumSchedulerWithStride( stride(from: device.cores-1, to: -1, by: -1), onlyIfIdle )
        } else {
            // preferEfficiency
            scheduler = minimumSchedulerWithStride( stride(from: 0, to: device.cores, by: 1), onlyIfIdle )
        }

        if let scheduler = scheduler {
            scheduler.schedule(actor)
            return true
        }
        return false*/
    }
}
