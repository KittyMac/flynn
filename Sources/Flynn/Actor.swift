//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import Pony

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
    internal let unsafePonyActor: UnsafeMutableRawPointer

    public var safePriority: Int32 {
        set { pony_actor_setpriority(unsafePonyActor, newValue) }
        get { return pony_actor_getpriority(unsafePonyActor) }
    }

    public var safeCoreAffinity: CoreAffinity {
        set { pony_actor_setcoreAffinity(unsafePonyActor, newValue.rawValue) }
        get { return CoreAffinity(rawValue: pony_actor_getcoreAffinity(unsafePonyActor))! }
    }

    // MARK: - Functions
    public func unsafeWait(_ minMsgs: Int32) {
        // Pause while waiting for this actor's message queue to reach 0
        pony_actor_wait(minMsgs, unsafePonyActor)
    }

    public func safeYield() {
        // Flag this actor yield the scheduler after this message
        pony_actor_yield(unsafePonyActor)
    }

    // While not 100% accurate, it can be helpful to know how large the
    // actor's mailbox size is in order to perform lite load balancing
    public var unsafeMessagesCount: Int32 {
        return pony_actor_num_messages(unsafePonyActor)
    }

    public init() {
        if Flynn.ponyIsStarted == false {
            Flynn.startup()
        }

        unsafePonyActor = pony_actor_create()
        uuid = UUID().uuidString

        pony_actor_attach(unsafePonyActor, self)
    }

    deinit {
        pony_actor_destroy(unsafePonyActor)
    }
}
