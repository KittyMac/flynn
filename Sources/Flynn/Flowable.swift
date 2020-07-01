//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

infix operator |> : AssignmentPrecedence
public func |> (left: Flowable, right: Flowable) -> Flowable {
    left.beTarget(right)
    return left
}
public func |> (left: Flowable, right: [Flowable]) -> Flowable {
    left.beTargets(right)
    return left
}
public func |> (left: [Flowable], right: Flowable) -> [Flowable] {
    for one in left {
        one.beTarget(right)
    }
    return left
}

public class FlowableState {
    private var actor: Actor
    fileprivate var numTargets: Int = 0
    fileprivate var flowTarget: Flowable?
    fileprivate var flowTargets: [Flowable] = []
    fileprivate var poolIdx: Int = 0

    private func _retryEndFlowToNextTarget() {
        switch self.numTargets {
        case 0:
            return
        case 1:
            flowTarget?.beFlow.dynamicallyFlow(withArguments: [])
        default:
            if actor.unsafeShouldWaitOnActors(flowTargets) {
                beRetryEndFlowToNextTarget()
                actor.unsafeYield()
                return
            }
            poolIdx = (poolIdx + 1) % numTargets
            flowTargets[poolIdx].beFlow.dynamicallyFlow(withArguments: [])
        }
    }

    fileprivate lazy var beRetryEndFlowToNextTarget = Behavior { [unowned self] (_: BehaviorArgs) in
        self._retryEndFlowToNextTarget()
    }

    public lazy var beTarget = Behavior { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter Flowable - Flowable actor to receive flow messages
        let localTarget: Flowable = args[x: 0]
        self.flowTarget = localTarget
        self.flowTargets.append(localTarget)
        self.numTargets = self.flowTargets.count
    }

    public lazy var beTargets = Behavior { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter [Flowable] - Pool of flowable actors to receive flow messages
        let localTargets: [Flowable] = args[x: 0]
        self.flowTarget = localTargets.first
        self.flowTargets.append(contentsOf: localTargets)
        self.numTargets = self.flowTargets.count
    }

    public init (_ actor: Actor) {
        self.actor = actor
        beTarget.setActor(actor)
        beTargets.setActor(actor)
        beRetryEndFlowToNextTarget.setActor(actor)
    }
}

public protocol Flowable: Actor {
    var safeFlowable: FlowableState { get set }

    var beFlow: Behavior { get set }
}

public extension Flowable {
    var beTarget: Behavior { return safeFlowable.beTarget }
    var beTargets: Behavior { return safeFlowable.beTargets }

    func safeNextTarget() -> Flowable? {
        switch safeFlowable.numTargets {
        case 0:
            return nil
        case 1:
            return safeFlowable.flowTarget
        default:
            safeFlowable.poolIdx = (safeFlowable.poolIdx + 1) % safeFlowable.numTargets
            return safeFlowable.flowTargets[safeFlowable.poolIdx]
        }
    }

    func safeFlowToNextTarget(_ args: BehaviorArgs) {
        switch safeFlowable.numTargets {
        case 0:
            return
        case 1:
            safeFlowable.flowTarget?.beFlow.dynamicallyFlow(withArguments: args)
        default:
            if args.isEmpty {
                if unsafeShouldWaitOnActors(safeFlowable.flowTargets) {
                    safeFlowable.beRetryEndFlowToNextTarget()
                    unsafeYield()
                    return
                }
            }
            safeFlowable.poolIdx = (safeFlowable.poolIdx + 1) % safeFlowable.numTargets
            safeFlowable.flowTargets[safeFlowable.poolIdx].beFlow.dynamicallyFlow(withArguments: args)
        }
    }
}
