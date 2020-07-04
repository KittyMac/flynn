//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

import Pony

#if !PLATFORM_SUPPORTS_PONYRT

open class Flynn {
    internal static var totalMessages: UnsafeMutableRawPointer?

#if DEBUG
    public static var checkForUnsafeArguments: Bool = true
#else
    public static var checkForUnsafeArguments: Bool = false
#endif

    public class func startup() {
        totalMessages = pony_create_atomic_counter()
    }

    public class func shutdown() {
        while pony_valueof_atomic_counter(totalMessages) > 0 {
            usleep(10000)
        }
    }

    public static var cores: Int {
        return ProcessInfo.processInfo.processorCount
    }
}

#endif
