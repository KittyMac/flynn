//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

/*
public extension Flynn {
    
    class Timer {
        var fireTime: TimeInterval = 0.0
        
        var cancelled: Bool = false
        
        let timeInterval: TimeInterval
        let repeats: Bool
        
        let behavior: AnyBehavior
        var args: BehaviorArgs
        
        @discardableResult
        public init(timeInterval: TimeInterval, repeats: Bool, _ behavior: AnyBehavior, _ args: BehaviorArgs) {
            self.timeInterval = timeInterval
            self.repeats = repeats
            self.behavior = behavior
            self.args = args
            self.args.append(self)
            
            schedule()
        }

        public func cancel() {
            cancelled = true
        }
                
        internal func schedule() {
            fireTime = ProcessInfo.processInfo.systemUptime + timeInterval
            Flynn.register(self)
        }
        
        internal func fire() {
            if cancelled {
                return
            }
            if behavior.dynamicallyCallMaybe(withArguments: args) == true {
                if repeats {
                    schedule()
                }
            } else {
                cancelled = true
            }
        }
    }
    
    internal static func clearRegisteredTimers() {
        registeredTimersQueue.clear()
    }
    
    private static var registeredTimersQueue = Queue<Timer>(size: 1024,
                                                            manyProducers: true,
                                                            manyConsumers: false)
    internal static func register(_ timer: Timer) {
        registeredTimersQueue.enqueue(timer, sortedBy: { (lhs, rhs) in
            return lhs.fireTime > rhs.fireTime
        })
        wakeTimerLoop()
    }
    
    @discardableResult
    fileprivate static func checkRegisteredTimers() -> TimeInterval {
        let currentTime = ProcessInfo.processInfo.systemUptime
        var nextTimerMinTime: TimeInterval = 10.0
        
        var completedTimers: [Flynn.Timer] = []
        
        registeredTimersQueue.dequeueAny { (timer) in
            let timeDelta = timer.fireTime - currentTime
            if timeDelta < 0 {
                completedTimers.append(timer)
                return true
            }
            if timeDelta < nextTimerMinTime {
                nextTimerMinTime = timeDelta
            }
            return false
        }
        
        for timer in completedTimers {
            timer.fire()
        }
                
        if nextTimerMinTime < 0 {
            nextTimerMinTime = 0
        }

        return nextTimerMinTime / 2
    }
    
    
    internal class TimerLoop {

        internal var idle: Bool
        internal var running: Bool

    #if os(Linux)
        private lazy var thread = Thread(block: run)
    #else
        private lazy var thread = Thread(target: self, selector: #selector(run), object: nil)
    #endif

        private var waitingForWorkSemaphore = DispatchSemaphore(value: 0)

        init() {
            running = true
            idle = false

            thread.name = "Flynn Timers"
            thread.qualityOfService = .default
            thread.start()
        }
        
        func wake() {
            waitingForWorkSemaphore.signal()
        }

        @objc func run() {
            while running {
                Flynn.checkRegisteredActors()
                let timeout = Flynn.checkRegisteredTimers()
                _ = waitingForWorkSemaphore.wait(timeout: DispatchTime.now() + timeout)
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
}

*/
