//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import Pony

public enum CoreAffinity: Int {
    case preferEfficiency = 0
    case preferPerformance = 1
    case onlyEfficiency = 2
    case onlyPerformance = 3
    case none = 99
}

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
    
    private static var timerLoop: TimerLoop?
    private static var running = AtomicContidion()
    private static var device = Device()

    private static var timeStart: TimeInterval = 0
    private static var registeredActorsCheckRunning = false

    public class func startup() {
        running.checkInactive {
            timeStart = ProcessInfo.processInfo.systemUptime

            timerLoop = TimerLoop()
                        
            pony_startup()
        }
    }

    public class func shutdown() {
        running.checkActive {
                        
            pony_shutdown()
            
            timerLoop?.join()
            timerLoop = nil
            
            // wait until the registered actors thread ends
            clearRegisteredActors()
            clearRegisteredTimers()
        }
    }

    public static var cores: Int {
        return device.cores
    }
    
    public static var eCores: Int {
        return device.eCores
    }
    
    public static var pCores: Int {
        return device.pCores
    }
        
    internal static func wakeTimerLoop() {
        timerLoop?.wake()
    }
}
