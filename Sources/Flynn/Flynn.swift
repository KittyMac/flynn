//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

#if PLATFORM_SUPPORTS_PONYRT
import Pony
#endif

open class Flynn {
    internal static var ponyIsStarted: Bool = false

#if DEBUG
    public static var checkForUnsafeArguments: Bool = true
#else
    public static var checkForUnsafeArguments: Bool = false
#endif

    public class func startup() {
        pony_startup()
        ponyIsStarted = true
    }

    public class func shutdown() {
        pony_shutdown()
        ponyIsStarted = false
    }

    public static var cores: Int {
        startup()
#if PLATFORM_SUPPORTS_PONYRT
        return Int(pony_cpu_count())
#else
        return ProcessInfo.processInfo.processorCount
#endif
    }

}
