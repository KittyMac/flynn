//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import Pony

infix operator |> : AssignmentPrecedence
public func |> (left: Actor, right: Actor) -> Actor {
    left.beTarget(right)
    return left
}
public func |> (left: Actor, right: [Actor]) -> Actor {
    left.beTargets(right)
    return left
}
public func |> (left: [Actor], right: Actor) -> [Actor] {
    for one in left {
        one.beTarget(right)
    }
    return left
}

open class Actor {
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

    // MARK: - Flow

    private var numTargets: Int = 0
    private var flowTarget: Actor?
    private var flowTargets: [Actor] = []
    private var ponyActorTargets: [UnsafeMutableRawPointer] = []
    private var poolIdx: Int = 0

    open func safeFlowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
        // overridden by subclasses to handle processing flowed requests
        return (true, args)
    }

    public func safeNextTarget() -> Actor? {
        switch numTargets {
        case 0:
            return nil
        case 1:
            return flowTarget
        default:
            poolIdx = (poolIdx + 1) % numTargets
            return flowTargets[poolIdx]
        }
    }

    private func _retryEndFlow(_ args: BehaviorArgs) {
        if numTargets > 1 && args.isEmpty {
            if pony_actors_should_wait(0, &ponyActorTargets, Int32(numTargets)) {
                retryEndFlow()
                safeYield()
                return
            }
        }

        if let target = safeNextTarget() {
            target.beFlow.dynamicallyCall(withArguments: args)
        }
    }

    private lazy var retryEndFlow = ChainableBehavior(self) { (args: BehaviorArgs) in
        self._retryEndFlow(args)
    }

    private func _flow(_ args: BehaviorArgs) {
        let (shouldFlow, newArgs) = safeFlowProcess(args: args)
        if shouldFlow {
            if numTargets > 1 && newArgs.isEmpty {
                if pony_actors_should_wait(0, &ponyActorTargets, Int32(numTargets)) {
                    retryEndFlow()
                    safeYield()
                    return
                }
            }

            if let target = safeNextTarget() {
                target.beFlow.dynamicallyCall(withArguments: newArgs)
            }
        }
    }

    public lazy var beFlow = ChainableBehavior(self) { (args: BehaviorArgs) in
        // flynnlint:parameter Any
        self._flow(args)
    }

    public lazy var beTarget = ChainableBehavior(self) { (args: BehaviorArgs) in
        // flynnlint:parameter Actor - Actor to receive flow messages
        let localTarget: Actor = args[x: 0]
        self.flowTarget = localTarget
        self.flowTargets.append(localTarget)
        self.ponyActorTargets.append(localTarget.unsafePonyActor)
        self.numTargets = self.flowTargets.count
    }

    public lazy var beTargets = ChainableBehavior(self) { (args: BehaviorArgs) in
        // flynnlint:parameter [Actor] - Pool of actors to receive flow messages
        let localTargets: [Actor] = args[x: 0]
        self.flowTarget = localTargets.first
        self.flowTargets.append(contentsOf: localTargets)
        for target in localTargets {
            self.ponyActorTargets.append(target.unsafePonyActor)
        }
        self.numTargets = self.flowTargets.count
    }
}
