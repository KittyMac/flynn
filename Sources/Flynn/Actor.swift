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

    public enum QualityOfService: Int32 {
        case any = 0
        case efficiency = 1
        case performance = 2
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

    public var safeQualityOfService: QualityOfService {
        set { pony_actor_setqualityOfService(unsafePonyActor, newValue.rawValue) }
        get { return QualityOfService(rawValue: pony_actor_getqualityOfService(unsafePonyActor))! }
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
    }

    deinit {
        pony_actor_destroy(unsafePonyActor)
    }
}
