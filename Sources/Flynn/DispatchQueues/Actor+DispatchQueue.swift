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

internal extension Actor {
    @discardableResult
    func unsafeRetain() -> Self {
        _ = Unmanaged.passRetained(self)
        return self
    }
    @discardableResult
    func unsafeRelease() -> Self {
        _ = Unmanaged.passUnretained(self).release()
        return self
    }
}

open class Actor {

    public enum CoreAffinity: Int32 {
        case preferEfficiency = 0
        case preferPerformance = 1
        case onlyEfficiency = 2
        case onlyPerformance = 3
    }

    private class func startup() {
        Flynn.startup()
    }

    private class func shutdown() {
        Flynn.shutdown()
    }

    private let uuid: String

    internal lazy var unsafeDispatchQueue = DispatchQueue(label: "actor.\(uuid).queue", qos: dispatchQoS)
    internal var unsafeMsgCount: UnsafeMutableRawPointer? = pony_create_atomic_counter()
    private var dispatchQoS: DispatchQoS = .userInitiated

    public var safePriority: Int32 {
        set { withExtendedLifetime(newValue) { } }
        get { return 0 }
    }

    public var safeCoreAffinity: CoreAffinity {
        set {
            switch newValue {
            case .onlyEfficiency, .preferEfficiency:
                dispatchQoS = .utility
            case .onlyPerformance, .preferPerformance:
                dispatchQoS = .userInitiated
            }
        }
        get { return CoreAffinity.preferEfficiency }
    }

    // MARK: - Functions
    public func unsafeWait(_ minMsgs: Int32 = 0) {
        // with dispatch queues we can only wait unti end
        if minMsgs > 0 {
            print("warning: Flynn (using dispatch queues) does not support waiting for message counts other than 0")
        }
        unsafeDispatchQueue.sync { }
    }

    public func unsafeYield() {
        // yielding is not supported with DispatchQueues
    }

    public func unsafeShouldWaitOnActors(_ actors: [Actor]) -> Bool {
        var num: Int = 0
        for actor in actors {
            num += actor.unsafeMessagesCount
        }
        return num > 0
    }

    public var unsafeMessagesCount: Int {
        return pony_valueof_atomic_counter(unsafeMsgCount)
    }

    public init() {
        Flynn.startup()
        uuid = UUID().uuidString

        // This is required because with programming patterns like
        // Actor().beBehavior() Swift will dealloc the actor prior
        // to the behavior being called.
        self.unsafeRetain()
        unsafeDispatchQueue.asyncAfter(deadline: .now() + 0.1) {
            self.unsafeRelease()
        }
    }

    deinit {
        //print("deinit - Actor")
        pony_destroy_atomic_counter(unsafeMsgCount)
    }
}

#endif
