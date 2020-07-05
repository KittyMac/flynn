//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

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

    public var safePriority: Int32 {
        set { withExtendedLifetime(newValue) { } }
        get { return 0 }
    }

    public var safeCoreAffinity: CoreAffinity = .preferEfficiency

    // MARK: - Functions
    public func unsafeWait(_ minMsgs: Int32 = 0) {
        while messages.count > minMsgs {
            usleep(10000)
        }
    }

    public func unsafeYield() {
        // yielding is not supported with DispatchQueues
    }

    public func unsafeShouldWaitOnActors(_ actors: [Actor]) -> Bool {
        var num: Int32 = 0
        for actor in actors {
            num += actor.unsafeMessagesCount
        }
        print(num)
        return num > 0
    }

    public var unsafeMessagesCount: Int32 {
        return Int32(messages.count)
    }

    public init() {
        Flynn.startup()
        uuid = UUID().uuidString

        // This is required because with programming patterns like
        // Actor().beBehavior() Swift will dealloc the actor prior
        // to the behavior being called.
        self.unsafeRetain()
    }

    deinit {
        print("deinit - Actor")
    }

    private var messages = Queue<(BehaviorBlock, BehaviorArgs)>()
    internal func unsafeSend(_ block: @escaping BehaviorBlock, _ args: BehaviorArgs) {
        if messages.enqueue((block, args)) {
            //print("schedule \(self)")
            Flynn.schedule(self)
        }
    }

    private var running: Bool = false
    private var runningLock = NSLock()
    internal func unsafeRun() -> Bool {
        if runningLock.try() {
            //print("run \(self)")
            while let msg = messages.dequeue() {
                //print("  msg for \(self)")
                msg.0(msg.1)
            }
            runningLock.unlock()
        }

        return !messages.markEmpty()
    }
}

#endif
