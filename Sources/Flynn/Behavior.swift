//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// swiftlint:disable force_cast
// swiftlint:disable cyclomatic_complexity
// swiftlint:disable line_length

import Foundation
import Pony

public typealias BehaviorArgs = [Any]

public extension Array {
    // Extract and convert a subscript all in one command. Since we don't have compiler
    // support for checking parameters with behaviors, I am leaning towards crashing
    // in order to help identify buggy code faster.
    func get<T>(_ idx: Int) -> T {
        return self[idx] as! T
    }
    subscript<T>(x idx: Int) -> T {
        return self[idx] as! T
    }

    func check(_ idx: Int) -> Any {
        return self[idx]
    }
}

public typealias BehaviorBlock = ((BehaviorArgs) -> Void)

private func failReferenceTypesToBehavior(_ arg: Any) {
    print("warning: passing \(type(of: arg)) to behavior can lead to data races (use value types instead)")
    print("         add symbolic breakpoint for failReferenceTypesToBehavior for more information")
}

private func checkReferenceTypesToBehavior(_ args: BehaviorArgs) {
    //for arg in args where type(of: arg) is AnyClass {
    for arg in args where type(of: arg) is AnyClass {
        if !(arg is Actor) && !(arg is Behavior) {
            failReferenceTypesToBehavior(arg)
        }
        break
    }
}

// Note: Ideally, we could use ChainableBehavior<T: Actor>, but there appears to
// be a bug in Swift which causes Actor to not be recognized when used with a protocol
@dynamicCallable
public class ChainableBehavior<T> {
    private let block: BehaviorBlock
    private var actor: T?
    private var actorAsActor: Actor?
    private var fastBlock0: UnsafeMutableRawPointer
    private var fastBlock1: UnsafeMutableRawPointer
    private var fastBlock2: UnsafeMutableRawPointer
    private var fastBlock3: UnsafeMutableRawPointer
    private var fastBlock4: UnsafeMutableRawPointer
    private var fastBlock5: UnsafeMutableRawPointer
    private var fastBlock6: UnsafeMutableRawPointer
    private var fastBlock7: UnsafeMutableRawPointer
    private var fastBlock8: UnsafeMutableRawPointer
    private var fastBlock9: UnsafeMutableRawPointer
    private var fastBlock10: UnsafeMutableRawPointer

    // Note: fastBlock will leak because structs in swift do not have deinit!
    public init(_ actor: T, _ block: @escaping BehaviorBlock) {
        self.actor = actor
        actorAsActor = actor as? Actor
        self.block = block
        fastBlock0 = pony_register_fast_block0({ () in block([]) })
        fastBlock1 = pony_register_fast_block1({ (arg0) in block([arg0!]) })
        fastBlock2 = pony_register_fast_block2({ (arg0, arg1) in block([arg0!, arg1!]) })
        fastBlock3 = pony_register_fast_block3({ (arg0, arg1, arg2) in block([arg0!, arg1!, arg2!]) })
        fastBlock4 = pony_register_fast_block4({ (arg0, arg1, arg2, arg3) in block([arg0!, arg1!, arg2!, arg3!]) })
        fastBlock5 = pony_register_fast_block5({ (arg0, arg1, arg2, arg3, arg4) in block([arg0!, arg1!, arg2!, arg3!, arg4!]) })
        fastBlock6 = pony_register_fast_block6({ (arg0, arg1, arg2, arg3, arg4, arg5) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!]) })
        fastBlock7 = pony_register_fast_block7({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!]) })
        fastBlock8 = pony_register_fast_block8({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!]) })
        fastBlock9 = pony_register_fast_block9({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!]) })
        fastBlock10 = pony_register_fast_block10({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!, arg9!]) })
    }

    public init(_ block: @escaping BehaviorBlock) {
        self.actor = nil
        actorAsActor = nil
        self.block = block
        fastBlock0 = pony_register_fast_block0({ () in block([]) })
        fastBlock1 = pony_register_fast_block1({ (arg0) in block([arg0!]) })
        fastBlock2 = pony_register_fast_block2({ (arg0, arg1) in block([arg0!, arg1!]) })
        fastBlock3 = pony_register_fast_block3({ (arg0, arg1, arg2) in block([arg0!, arg1!, arg2!]) })
        fastBlock4 = pony_register_fast_block4({ (arg0, arg1, arg2, arg3) in block([arg0!, arg1!, arg2!, arg3!]) })
        fastBlock5 = pony_register_fast_block5({ (arg0, arg1, arg2, arg3, arg4) in block([arg0!, arg1!, arg2!, arg3!, arg4!]) })
        fastBlock6 = pony_register_fast_block6({ (arg0, arg1, arg2, arg3, arg4, arg5) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!]) })
        fastBlock7 = pony_register_fast_block7({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!]) })
        fastBlock8 = pony_register_fast_block8({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!]) })
        fastBlock9 = pony_register_fast_block9({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!]) })
        fastBlock10 = pony_register_fast_block10({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!, arg9!]) })
    }

    deinit {
        pony_unregister_fast_block(fastBlock0)
        pony_unregister_fast_block(fastBlock1)
        pony_unregister_fast_block(fastBlock2)
        pony_unregister_fast_block(fastBlock3)
        pony_unregister_fast_block(fastBlock4)
        pony_unregister_fast_block(fastBlock5)
        pony_unregister_fast_block(fastBlock6)
        pony_unregister_fast_block(fastBlock7)
        pony_unregister_fast_block(fastBlock8)
        pony_unregister_fast_block(fastBlock9)
        pony_unregister_fast_block(fastBlock10)
    }

    public func setActor(_ actor: T) {
        self.actor = actor
        self.actorAsActor = actor as? Actor
    }

    @discardableResult public func dynamicallyCall(withArguments args: BehaviorArgs) -> T {
        #if DEBUG
        checkReferenceTypesToBehavior(args)
        #endif

        switch args.count {
        case 1: pony_actor_fast_dispatch1(actorAsActor!.unsafePonyActor, args[0], fastBlock1)
        case 2: pony_actor_fast_dispatch2(actorAsActor!.unsafePonyActor, args[0], args[1], fastBlock2)
        case 3: pony_actor_fast_dispatch3(actorAsActor!.unsafePonyActor, args[0], args[1], args[2], fastBlock3)
        case 4: pony_actor_fast_dispatch4(actorAsActor!.unsafePonyActor, args[0], args[1], args[2], args[3], fastBlock4)
        case 5: pony_actor_fast_dispatch5(actorAsActor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], fastBlock5)
        case 6: pony_actor_fast_dispatch6(actorAsActor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], fastBlock6)
        case 7: pony_actor_fast_dispatch7(actorAsActor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], fastBlock7)
        case 8: pony_actor_fast_dispatch8(actorAsActor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], fastBlock8)
        case 9: pony_actor_fast_dispatch9(actorAsActor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], fastBlock9)
        case 10: pony_actor_fast_dispatch10(actorAsActor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], fastBlock10)
        default: pony_actor_fast_dispatch0(actorAsActor!.unsafePonyActor, fastBlock0)
        }

        return actor!
    }

    @discardableResult public func dynamicallyFlow(withArguments args: BehaviorArgs) -> T {
        switch args.count {
        case 1: pony_actor_fast_dispatch1(actorAsActor!.unsafePonyActor, args[0], fastBlock1)
        case 2: pony_actor_fast_dispatch2(actorAsActor!.unsafePonyActor, args[0], args[1], fastBlock2)
        case 3: pony_actor_fast_dispatch3(actorAsActor!.unsafePonyActor, args[0], args[1], args[2], fastBlock3)
        case 4: pony_actor_fast_dispatch4(actorAsActor!.unsafePonyActor, args[0], args[1], args[2], args[3], fastBlock4)
        case 5: pony_actor_fast_dispatch5(actorAsActor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], fastBlock5)
        case 6: pony_actor_fast_dispatch6(actorAsActor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], fastBlock6)
        case 7: pony_actor_fast_dispatch7(actorAsActor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], fastBlock7)
        case 8: pony_actor_fast_dispatch8(actorAsActor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], fastBlock8)
        case 9: pony_actor_fast_dispatch9(actorAsActor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], fastBlock9)
        case 10: pony_actor_fast_dispatch10(actorAsActor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], fastBlock10)
        default: pony_actor_fast_dispatch0(actorAsActor!.unsafePonyActor, fastBlock0)
        }

        return actor!
    }
}

@dynamicCallable
public class Behavior {
    private let block: BehaviorBlock
    private var actor: Actor?
    private var fastBlock0: UnsafeMutableRawPointer
    private var fastBlock1: UnsafeMutableRawPointer
    private var fastBlock2: UnsafeMutableRawPointer
    private var fastBlock3: UnsafeMutableRawPointer
    private var fastBlock4: UnsafeMutableRawPointer
    private var fastBlock5: UnsafeMutableRawPointer
    private var fastBlock6: UnsafeMutableRawPointer
    private var fastBlock7: UnsafeMutableRawPointer
    private var fastBlock8: UnsafeMutableRawPointer
    private var fastBlock9: UnsafeMutableRawPointer
    private var fastBlock10: UnsafeMutableRawPointer

    // Note: _fastBlock will leak because structs in swift do not have deinit!
    public init(_ actor: Actor, _ block: @escaping BehaviorBlock) {
        self.actor = actor
        self.block = block
        fastBlock0 = pony_register_fast_block0({ () in block([]) })
        fastBlock1 = pony_register_fast_block1({ (arg0) in block([arg0!]) })
        fastBlock2 = pony_register_fast_block2({ (arg0, arg1) in block([arg0!, arg1!]) })
        fastBlock3 = pony_register_fast_block3({ (arg0, arg1, arg2) in block([arg0!, arg1!, arg2!]) })
        fastBlock4 = pony_register_fast_block4({ (arg0, arg1, arg2, arg3) in block([arg0!, arg1!, arg2!, arg3!]) })
        fastBlock5 = pony_register_fast_block5({ (arg0, arg1, arg2, arg3, arg4) in block([arg0!, arg1!, arg2!, arg3!, arg4!]) })
        fastBlock6 = pony_register_fast_block6({ (arg0, arg1, arg2, arg3, arg4, arg5) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!]) })
        fastBlock7 = pony_register_fast_block7({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!]) })
        fastBlock8 = pony_register_fast_block8({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!]) })
        fastBlock9 = pony_register_fast_block9({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!]) })
        fastBlock10 = pony_register_fast_block10({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!, arg9!]) })
    }

    public init(_ block: @escaping BehaviorBlock) {
        self.actor = nil
        self.block = block
        fastBlock0 = pony_register_fast_block0({ () in block([]) })
        fastBlock1 = pony_register_fast_block1({ (arg0) in block([arg0!]) })
        fastBlock2 = pony_register_fast_block2({ (arg0, arg1) in block([arg0!, arg1!]) })
        fastBlock3 = pony_register_fast_block3({ (arg0, arg1, arg2) in block([arg0!, arg1!, arg2!]) })
        fastBlock4 = pony_register_fast_block4({ (arg0, arg1, arg2, arg3) in block([arg0!, arg1!, arg2!, arg3!]) })
        fastBlock5 = pony_register_fast_block5({ (arg0, arg1, arg2, arg3, arg4) in block([arg0!, arg1!, arg2!, arg3!, arg4!]) })
        fastBlock6 = pony_register_fast_block6({ (arg0, arg1, arg2, arg3, arg4, arg5) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!]) })
        fastBlock7 = pony_register_fast_block7({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!]) })
        fastBlock8 = pony_register_fast_block8({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!]) })
        fastBlock9 = pony_register_fast_block9({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!]) })
        fastBlock10 = pony_register_fast_block10({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!, arg9!]) })
    }

    deinit {
        pony_unregister_fast_block(fastBlock0)
        pony_unregister_fast_block(fastBlock1)
        pony_unregister_fast_block(fastBlock2)
        pony_unregister_fast_block(fastBlock3)
        pony_unregister_fast_block(fastBlock4)
        pony_unregister_fast_block(fastBlock5)
        pony_unregister_fast_block(fastBlock6)
        pony_unregister_fast_block(fastBlock7)
        pony_unregister_fast_block(fastBlock8)
        pony_unregister_fast_block(fastBlock9)
        pony_unregister_fast_block(fastBlock10)
    }

    public func setActor(_ actor: Actor) {
        self.actor = actor
    }

    public func dynamicallyCall(withArguments args: BehaviorArgs) {
        #if DEBUG
        checkReferenceTypesToBehavior(args)
        #endif

        switch args.count {
        case 1: pony_actor_fast_dispatch1(actor!.unsafePonyActor, args[0], fastBlock1)
        case 2: pony_actor_fast_dispatch2(actor!.unsafePonyActor, args[0], args[1], fastBlock2)
        case 3: pony_actor_fast_dispatch3(actor!.unsafePonyActor, args[0], args[1], args[2], fastBlock3)
        case 4: pony_actor_fast_dispatch4(actor!.unsafePonyActor, args[0], args[1], args[2], args[3], fastBlock4)
        case 5: pony_actor_fast_dispatch5(actor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], fastBlock5)
        case 6: pony_actor_fast_dispatch6(actor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], fastBlock6)
        case 7: pony_actor_fast_dispatch7(actor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], fastBlock7)
        case 8: pony_actor_fast_dispatch8(actor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], fastBlock8)
        case 9: pony_actor_fast_dispatch9(actor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], fastBlock9)
        case 10: pony_actor_fast_dispatch10(actor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], fastBlock10)
        default: pony_actor_fast_dispatch0(actor!.unsafePonyActor, fastBlock0)
        }
    }

    public func dynamicallyFlow(withArguments args: BehaviorArgs) {
        switch args.count {
        case 1: pony_actor_fast_dispatch1(actor!.unsafePonyActor, args[0], fastBlock1)
        case 2: pony_actor_fast_dispatch2(actor!.unsafePonyActor, args[0], args[1], fastBlock2)
        case 3: pony_actor_fast_dispatch3(actor!.unsafePonyActor, args[0], args[1], args[2], fastBlock3)
        case 4: pony_actor_fast_dispatch4(actor!.unsafePonyActor, args[0], args[1], args[2], args[3], fastBlock4)
        case 5: pony_actor_fast_dispatch5(actor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], fastBlock5)
        case 6: pony_actor_fast_dispatch6(actor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], fastBlock6)
        case 7: pony_actor_fast_dispatch7(actor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], fastBlock7)
        case 8: pony_actor_fast_dispatch8(actor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], fastBlock8)
        case 9: pony_actor_fast_dispatch9(actor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], fastBlock9)
        case 10: pony_actor_fast_dispatch10(actor!.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], fastBlock10)
        default: pony_actor_fast_dispatch0(actor!.unsafePonyActor, fastBlock0)
        }
    }
}
