//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

extension Flynn {
    
    public class Timer {
        var fireTime: TimeInterval = 0.0
        
        var cancelled: Bool = false
        
        let timeInterval: TimeInterval
        let repeats: Bool
        
        let behavior: AnyBehavior
        let args: BehaviorArgs
        
        @discardableResult
        init(timeInterval: TimeInterval, repeats: Bool, _ behavior: AnyBehavior, _ args: BehaviorArgs) {
            self.timeInterval = timeInterval
            self.repeats = repeats
            self.behavior = behavior
            self.args = args
            
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
    
    private static var registeredTimersQueue = Queue<Timer>(1024, true, true, true)
    internal static func register(_ timer: Timer) {
        registeredTimersQueue.enqueue(timer, sortedBy: { (lhs, rhs) in
            return lhs.fireTime > rhs.fireTime
        })
        
        // the "0" scheduler is our timer checker. Send it a signal so it can
        // reset its signal timeout to match the new timer time
        wakeScheduler(0)
    }
    
    @discardableResult
    internal static func checkRegisteredTimers() -> TimeInterval {
        let currentTime = ProcessInfo.processInfo.systemUptime
        var timeTillNext: TimeInterval = 1.0
        
        let timerIsDone = { (timer: Timer) -> Bool in
            timeTillNext = timer.fireTime - currentTime
            return timer.fireTime <= currentTime
        }
        
        while let timer = registeredTimersQueue.dequeueIf(timerIsDone) {
            timer.fire()
        }
        
        if timeTillNext < 0 {
            timeTillNext = 0
        }
        return timeTillNext
    }
    
}
