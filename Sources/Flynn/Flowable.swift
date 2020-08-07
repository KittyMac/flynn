//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// swiftlint:disable force_cast

import Foundation

public typealias FlowableArgs = [Any?]

public extension Array {
    // Extract and convert a subscript all in one command. Since we don't have compiler
    // support for checking parameters with behaviors, I am leaning towards crashing
    // in order to help identify buggy code faster.
    @inline(__always)
    func get<T>(_ idx: Int) -> T {
        return self[idx] as! T
    }
    @inline(__always)
    subscript<T>(x idx: Int) -> T {
        return self[idx] as! T
    }
    @inline(__always)
    func check(_ idx: Int) -> Any {
        return self[idx]
    }
}

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
    fileprivate var numTargets: Int = 0
    fileprivate var flowTarget: Flowable?
    fileprivate var flowTargets: [Flowable] = []
    fileprivate var poolIdx: Int = 0

    public init() {

    }

    fileprivate func nextTarget() -> Flowable {
        poolIdx = (poolIdx + 1) % numTargets
        return flowTargets[poolIdx]
    }

    fileprivate func flowTarget(_ args: FlowableArgs) {
        flowTarget?.beFlow(args)
    }

    fileprivate func flowNextTarget(_ args: FlowableArgs) {
        poolIdx = (poolIdx + 1) % numTargets
        flowTargets[poolIdx].beFlow(args)
    }

    fileprivate func shouldWaitOnTargets() -> Bool {
        for actor in flowTargets where actor.unsafeMessagesCount > 0 {
            return true
        }
        return false
    }

    fileprivate func _beRetryEndFlowToNextTarget(_ actor: Flowable) {
        switch self.numTargets {
        case 0:
            return
        case 1:
            flowTarget?.beFlow([])
        default:
            if shouldWaitOnTargets() {
                beRetryEndFlowToNextTarget(actor)
                actor.unsafeYield()
                return
            }
            nextTarget().beFlow([])
        }
    }
    fileprivate func beRetryEndFlowToNextTarget(_ actor: Flowable) {
        actor.unsafeSend {
            self._beRetryEndFlowToNextTarget(actor)
        }
    }

    fileprivate func _beTarget(_ localTarget: Flowable) {
        self.flowTarget = localTarget
        self.flowTargets.append(localTarget)
        self.numTargets = self.flowTargets.count
    }

    fileprivate func _beTargets(_ localTargets: [Flowable]) {
        self.flowTarget = localTargets.first
        self.flowTargets.append(contentsOf: localTargets)
        self.numTargets = self.flowTargets.count
    }
}

public protocol Flowable: Actor {
    var safeFlowable: FlowableState { get set }

    func beTarget(_ target: Flowable)
    func beTargets(_ targets: [Flowable])

    func beFlow(_ args: FlowableArgs)
}

public extension Flowable {

    func beTarget(_ target: Flowable) {
        unsafeSend {
            self.safeFlowable._beTarget(target)
        }
    }
    func beTargets(_ targets: [Flowable]) {
        unsafeSend {
            self.safeFlowable._beTargets(targets)
        }
    }

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

    func safeFlowToNextTarget(_ args: FlowableArgs) {
        switch safeFlowable.numTargets {
        case 0:
            return
        case 1:
            safeFlowable.flowTarget(args)
        default:
            if args.isEmpty {
                if safeFlowable.shouldWaitOnTargets() {
                    safeFlowable.beRetryEndFlowToNextTarget(self)
                    unsafeYield()
                    return
                }
            }
            safeFlowable.flowNextTarget(args)
        }
    }
}
