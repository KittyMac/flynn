//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

#if !PLATFORM_SUPPORTS_PONYRT

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
    internal static var totalMessages = AtomicCount()

#if DEBUG
    public static var checkForUnsafeArguments: Bool = true
#else
    public static var checkForUnsafeArguments: Bool = false
#endif

    public class func startup() {

    }

    public class func shutdown() {
        while totalMessages.value > 0 {
            usleep(10000)
        }
    }

    public static var cores: Int {
        return ProcessInfo.processInfo.processorCount
    }
}

#endif
