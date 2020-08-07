//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

/*
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
public func |> (left: [Flowable], right: [Flowable]) -> [Flowable] {
    for one in left {
        one.beTargets(right)
    }
    return left
}

public class FlowableState {
    private weak var actor: Actor?
    fileprivate var numTargets: Int = 0
    fileprivate var flowTarget: Flowable?
    fileprivate var flowTargets: [Flowable] = []
    fileprivate var poolIdx: Int = 0

    fileprivate func nextTarget() -> Flowable {
        poolIdx = (poolIdx + 1) % numTargets
        return flowTargets[poolIdx]
    }
    
    fileprivate func flowTarget(_ args: BehaviorArgs) {
        flowTarget?.beFlow.dynamicallyFlow(withArguments: args)
    }

    fileprivate func flowNextTarget(_ args: BehaviorArgs) {
        poolIdx = (poolIdx + 1) % numTargets
        flowTargets[poolIdx].beFlow.dynamicallyFlow(withArguments: args)
    }
    
    fileprivate func shouldWaitOnTargets() -> Bool {
        for actor in flowTargets where actor.unsafeMessagesCount > 0 {
            return true
        }
        return false
    }

    fileprivate lazy var beRetryEndFlowToNextTarget = Behavior { [unowned self] (_: BehaviorArgs) in
        self._beRetryEndFlowToNextTarget()
    }
    private func _beRetryEndFlowToNextTarget() {
        switch self.numTargets {
        case 0:
            return
        case 1:
            flowTarget?.beFlow.dynamicallyFlow(withArguments: [])
        default:
            if shouldWaitOnTargets() {
                beRetryEndFlowToNextTarget()
                actor?.unsafeYield()
                return
            }
            nextTarget().beFlow.dynamicallyFlow(withArguments: [])
        }
    }

    lazy var beTarget = Behavior { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter Flowable - Flowable actor to receive flow messages
        let localTarget: Flowable = args[x: 0]
        self.flowTarget = localTarget
        self.flowTargets.append(localTarget)
        self.numTargets = self.flowTargets.count
    }

    lazy var beTargets = Behavior { [unowned self] (args: BehaviorArgs) in
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
            return safeFlowable.nextTarget()
        }
    }

    func safeFlowToNextTarget(_ args: BehaviorArgs) {
        switch safeFlowable.numTargets {
        case 0:
            return
        case 1:
            safeFlowable.flowTarget(args)
        default:
            if args.isEmpty {
                if safeFlowable.shouldWaitOnTargets() {
                    safeFlowable.beRetryEndFlowToNextTarget()
                    unsafeYield()
                    return
                }
            }
            safeFlowable.flowNextTarget(args)
        }
    }
}
*/
