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
    fileprivate var numTargets: Int = 0
    fileprivate var flowTarget: Flowable?
    fileprivate var flowTargets: [Flowable] = []
    fileprivate var ponyActorTargets: [UnsafeMutableRawPointer] = []
    fileprivate var poolIdx: Int = 0

    public lazy var beTarget = Behavior { (args: BehaviorArgs) in
        // flynnlint:parameter Flowable - Flowable actor to receive flow messages
        let localTarget: Flowable = args[x: 0]
        self.flowTarget = localTarget
        self.flowTargets.append(localTarget)
        self.ponyActorTargets.append(localTarget.unsafePonyActor)
        self.numTargets = self.flowTargets.count
    }

    public lazy var beTargets = Behavior { (args: BehaviorArgs) in
        // flynnlint:parameter [Flowable] - Pool of flowable actors to receive flow messages
        let localTargets: [Flowable] = args[x: 0]
        self.flowTarget = localTargets.first
        self.flowTargets.append(contentsOf: localTargets)
        for target in localTargets {
            self.ponyActorTargets.append(target.unsafePonyActor)
        }
        self.numTargets = self.flowTargets.count
    }

    public init (_ actor: Actor) {
        beTarget.setActor(actor)
        beTargets.setActor(actor)
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
            safeFlowable.flowTarget?.beFlow.dynamicallyCall(withArguments: args)
        default:
            if args.isEmpty {
                if pony_actors_should_wait(0, &safeFlowable.ponyActorTargets, Int32(safeFlowable.numTargets)) {
                    safeFlowToNextTarget(args)
                    safeYield()
                    return
                }
            }
            safeFlowable.poolIdx = (safeFlowable.poolIdx + 1) % safeFlowable.numTargets
            safeFlowable.flowTargets[safeFlowable.poolIdx].beFlow.dynamicallyCall(withArguments: args)
        }
    }
}
