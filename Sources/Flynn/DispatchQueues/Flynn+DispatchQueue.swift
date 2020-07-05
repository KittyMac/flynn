//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

#if !PLATFORM_SUPPORTS_PONYRT

class AtomicContidion {
    private var _value: Bool = false
    private var lock = NSLock()

    func check(_ block: () -> Void) {
        if _value == false {
            lock.lock()
            if _value == false {
                _value = true
                block()
            }
            lock.unlock()
        }
    }
}

class AtomicCount {
    private var _value: Int32 = 0
    private var lock = NSLock()

    func inc() {
        lock.lock()
        _value += 1
        lock.unlock()
    }

    func dec() {
        lock.lock()
        _value -= 1
        lock.unlock()
    }

    var value: Int32 {
        return _value
    }

}

open class Flynn {
#if DEBUG
    public static var checkForUnsafeArguments: Bool = true
#else
    public static var checkForUnsafeArguments: Bool = false
#endif

    private static var schedulers: [Scheduler] = []
    private static var schedulerIdx: Int = 0
    private static var running = AtomicContidion()

    public class func startup() {
        running.check {
            for _ in 0..<cores {
                schedulers.append(Scheduler(.onlyPerformance))
            }
        }
    }

    public class func shutdown() {
        for scheduler in schedulers {
            scheduler.join()
        }
    }

    public static var cores: Int {
        // TODO: no hyperthreads pls!
        return ProcessInfo.processInfo.processorCount / 2
    }

    public static func schedule(_ actor: Actor) {
        schedulers[schedulerIdx].schedule(actor)
        schedulerIdx = (schedulerIdx + 1) % schedulers.count
    }
}

#endif
