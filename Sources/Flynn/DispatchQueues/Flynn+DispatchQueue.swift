//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

#if !PLATFORM_SUPPORTS_PONYRT

open class Flynn {
    internal static var totalMessages: Int32 = 0

#if DEBUG
    public static var checkForUnsafeArguments: Bool = true
#else
    public static var checkForUnsafeArguments: Bool = false
#endif

    public class func startup() {

    }

    public class func shutdown() {
        while totalMessages > 0 {
            usleep(10000)
        }
    }

    public static var cores: Int {
        return ProcessInfo.processInfo.processorCount
    }
}

#endif
