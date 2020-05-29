//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import Flynn.Pony

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
    internal static var ponyIsStarted: Bool = false

    open class func startup() {
        pony_startup()
        ponyIsStarted = true
    }

    open class func shutdown() {
        pony_shutdown()
        ponyIsStarted = false
    }

    internal let uuid: String

    internal var numTargets: Int = 0
    internal var flowTarget: Actor?
    internal var flowTargets: [Actor]
    internal var ponyActorTargets: [UnsafeMutableRawPointer]
    internal let ponyActor: UnsafeMutableRawPointer

    internal var poolIdx: Int = 0

    func protected_flowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
        // overridden by subclasses to handle processing flowed requests
        return (true, args)
    }

    // MARK: - Behaviors
    private func sharedFlow(_ args: BehaviorArgs) {
        let (shouldFlow, newArgs) = protected_flowProcess(args: args)
        if shouldFlow {
            switch numTargets {
            case 0:
                return
            case 1:
                flowTarget?.flow.dynamicallyCall(withArguments: newArgs)
            default:
                if newArgs.isEmpty {
                    var ponyActors = ponyActorTargets
                    // If we're sending the "end of flow" item, and we have more than one target, then we
                    // need to delay sending this item until all of the targets have finished processing
                    // all of their messages.  Otherwise we can have a race condition.
                    pony_actors_wait(0, &ponyActors, Int32(numTargets))
                }

                poolIdx = (poolIdx + 1) % numTargets
                flowTargets[poolIdx].flow.dynamicallyCall(withArguments: newArgs)
            }
        }
    }

    lazy var flow = ChainableBehavior(self) { (args: BehaviorArgs) in
        self.sharedFlow(args)
    }

    lazy var target = ChainableBehavior(self) { (args: BehaviorArgs) in
        let localTarget: Actor = args[x: 0]
        self.flowTarget = localTarget
        self.flowTargets.append(localTarget)
        self.ponyActorTargets.append(localTarget.ponyActor)
        self.numTargets = self.flowTargets.count
    }

    lazy var targets = ChainableBehavior(self) { (args: BehaviorArgs) in
        let localTargets: [Actor] = args[x: 0]
        self.flowTarget = localTargets.first
        self.flowTargets.append(contentsOf: localTargets)
        for target in localTargets {
            self.ponyActorTargets.append(target.ponyActor)
        }
        self.numTargets = self.flowTargets.count
    }

    // MARK: - Functions
    func wait(_ minMsgs: Int32) {
        // Pause while waiting for this actor's message queue to reach 0
        var myPonyActor = ponyActor
        pony_actors_wait(minMsgs, &myPonyActor, 1)
    }

    // While not 100% accurate, it can be helpful to know how large the
    // actor's mailbox size is in order to perform lite load balancing
    var messagesCount: Int32 {
        return pony_actor_num_messages(ponyActor)
    }

    public init() {
        if Actor.ponyIsStarted == false {
            Actor.startup()
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
