//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import Pony

public typealias ActorBlock = (() -> Void)

infix operator |> : AssignmentPrecedence
public func |> (left: Actor, right: Actor) -> Actor {
    left.target(right)
    return left
}
public func |> (left: Actor, right: [Actor]) -> Actor {
    left.targets(right)
    return left
}
public func |> (left: [Actor], right: Actor) -> [Actor] {
    for one in left {
        one.target(right)
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

    internal let uuid: String

    internal var numTargets: Int = 0
    internal var flowTarget: Actor?
    internal var flowTargets: [Actor]
    internal var ponyActorTargets: [UnsafeMutableRawPointer]
    internal let ponyActor: UnsafeMutableRawPointer

    internal var poolIdx: Int = 0

    public var priority: Int32 {
        set { pony_actor_setpriority(ponyActor, newValue) }
        get { return pony_actor_getpriority(ponyActor) }
    }

    open func protected_flowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
        // overridden by subclasses to handle processing flowed requests
        return (true, args)
    }

    public func protected_nextTarget() -> Actor? {
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
            var ponyActors = ponyActorTargets
            if pony_actors_should_wait(0, &ponyActors, Int32(numTargets)) {
                retryEndFlow()
                yield()
                return
            }
        }

        if let target = protected_nextTarget() {
            target.flow.dynamicallyCall(withArguments: args)
        }
    }

    private lazy var retryEndFlow = ChainableBehavior(self) { (args: BehaviorArgs) in
        self._retryEndFlow(args)
    }

    // MARK: - Behaviors
    private func _flow(_ args: BehaviorArgs) {
        let (shouldFlow, newArgs) = protected_flowProcess(args: args)
        if shouldFlow {
            if numTargets > 1 && newArgs.isEmpty {
                var ponyActors = ponyActorTargets
                if pony_actors_should_wait(0, &ponyActors, Int32(numTargets)) {
                    retryEndFlow()
                    yield()
                    return
                }
            }

            if let target = protected_nextTarget() {
                target.flow.dynamicallyCall(withArguments: newArgs)
            }
        }
    }

    public lazy var flow = ChainableBehavior(self) { (args: BehaviorArgs) in
        self._flow(args)
    }

    public lazy var target = ChainableBehavior(self) { (args: BehaviorArgs) in
        let localTarget: Actor = args[x: 0]
        self.flowTarget = localTarget
        self.flowTargets.append(localTarget)
        self.ponyActorTargets.append(localTarget.ponyActor)
        self.numTargets = self.flowTargets.count
    }

    public lazy var targets = ChainableBehavior(self) { (args: BehaviorArgs) in
        let localTargets: [Actor] = args[x: 0]
        self.flowTarget = localTargets.first
        self.flowTargets.append(contentsOf: localTargets)
        for target in localTargets {
            self.ponyActorTargets.append(target.ponyActor)
        }
        self.numTargets = self.flowTargets.count
    }

    // MARK: - Functions
    public func wait(_ minMsgs: Int32) {
        // Pause while waiting for this actor's message queue to reach 0
        pony_actor_wait(minMsgs, ponyActor)
    }

    public func yield() {
        // Flag this actor yield the scheduler after this message
        pony_actor_yield(ponyActor)
    }

    // While not 100% accurate, it can be helpful to know how large the
    // actor's mailbox size is in order to perform lite load balancing
    public var messagesCount: Int32 {
        return pony_actor_num_messages(ponyActor)
    }

    public init() {
        if Flynn.ponyIsStarted == false {
            Flynn.startup()
        }

        ponyActor = pony_actor_create()

        uuid = UUID().uuidString
        flowTarget = nil
        flowTargets = []
        ponyActorTargets = []
    }

    deinit {
        pony_actor_destroy(ponyActor)
    }
}
