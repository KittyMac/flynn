//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// swiftlint:disable cyclomatic_complexity
// swiftlint:disable line_length

import Foundation
import Flynn.Pony

public typealias BehaviorArgs = [Any]

public extension Array {
    // Extract and convert a subscript all in one command. Since we don't have compiler
    // support for checking parameters with behaviors, I am leaning towards crashing
    // in order to help identify buggy code faster.
    func get<T>(_ idx: Int) -> T {
        return self[idx] as! T // swiftlint:disable:this force_cast
    }
    subscript<T>(x idx: Int) -> T {
        return self[idx] as! T // swiftlint:disable:this force_cast
    }

    func check(_ idx: Int) -> Any {
        return self[idx]
    }
}

public typealias FastDispatchBlock = (@convention(block) (Any) -> Void )
public typealias BehaviorBlock = ((BehaviorArgs) -> Void)

@dynamicCallable
public struct ChainableBehavior<T: Actor> {
    let actor: T
    let block: BehaviorBlock
    var fastBlock0: UnsafeMutableRawPointer
    var fastBlock1: UnsafeMutableRawPointer
    var fastBlock2: UnsafeMutableRawPointer
    var fastBlock3: UnsafeMutableRawPointer
    var fastBlock4: UnsafeMutableRawPointer
    var fastBlock5: UnsafeMutableRawPointer
    var fastBlock6: UnsafeMutableRawPointer
    var fastBlock7: UnsafeMutableRawPointer
    var fastBlock8: UnsafeMutableRawPointer
    var fastBlock9: UnsafeMutableRawPointer
    var fastBlock10: UnsafeMutableRawPointer

    // Note: fastBlock will leak because structs in swift do not have deinit!
    public init(_ actor: T, _ block: @escaping BehaviorBlock) {
        self.actor = actor
        self.block = block
        self.fastBlock0 = pony_register_fast_block0({ () in block([]) })
        self.fastBlock1 = pony_register_fast_block1({ (arg0) in block([arg0!]) })
        self.fastBlock2 = pony_register_fast_block2({ (arg0, arg1) in block([arg0!, arg1!]) })
        self.fastBlock3 = pony_register_fast_block3({ (arg0, arg1, arg2) in block([arg0!, arg1!, arg2!]) })
        self.fastBlock4 = pony_register_fast_block4({ (arg0, arg1, arg2, arg3) in block([arg0!, arg1!, arg2!, arg3!]) })
        self.fastBlock5 = pony_register_fast_block5({ (arg0, arg1, arg2, arg3, arg4) in block([arg0!, arg1!, arg2!, arg3!, arg4!]) })
        self.fastBlock6 = pony_register_fast_block6({ (arg0, arg1, arg2, arg3, arg4, arg5) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!]) })
        self.fastBlock7 = pony_register_fast_block7({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!]) })
        self.fastBlock8 = pony_register_fast_block8({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!]) })
        self.fastBlock9 = pony_register_fast_block9({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!]) })
        self.fastBlock10 = pony_register_fast_block10({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!, arg9!]) })
    }

    @discardableResult public func dynamicallyCall(withArguments args: BehaviorArgs) -> T {
        switch args.count {
        case 1: pony_actor_fast_dispatch1(actor.ponyActor, args[0], fastBlock1)
        case 2: pony_actor_fast_dispatch2(actor.ponyActor, args[0], args[1], fastBlock2)
        case 3: pony_actor_fast_dispatch3(actor.ponyActor, args[0], args[1], args[2], fastBlock3)
        case 4: pony_actor_fast_dispatch4(actor.ponyActor, args[0], args[1], args[2], args[3], fastBlock4)
        case 5: pony_actor_fast_dispatch5(actor.ponyActor, args[0], args[1], args[2], args[3], args[4], fastBlock5)
        case 6: pony_actor_fast_dispatch6(actor.ponyActor, args[0], args[1], args[2], args[3], args[4], args[5], fastBlock6)
        case 7: pony_actor_fast_dispatch7(actor.ponyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], fastBlock7)
        case 8: pony_actor_fast_dispatch8(actor.ponyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], fastBlock8)
        case 9: pony_actor_fast_dispatch9(actor.ponyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], fastBlock9)
        case 10: pony_actor_fast_dispatch10(actor.ponyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], fastBlock10)
        default: pony_actor_fast_dispatch0(actor.ponyActor, fastBlock0)
        }

        return actor
    }
}

@dynamicCallable
public struct Behavior {
    let actor: Actor
    let block: BehaviorBlock
    var fastBlock0: UnsafeMutableRawPointer
    var fastBlock1: UnsafeMutableRawPointer
    var fastBlock2: UnsafeMutableRawPointer
    var fastBlock3: UnsafeMutableRawPointer
    var fastBlock4: UnsafeMutableRawPointer
    var fastBlock5: UnsafeMutableRawPointer
    var fastBlock6: UnsafeMutableRawPointer
    var fastBlock7: UnsafeMutableRawPointer
    var fastBlock8: UnsafeMutableRawPointer
    var fastBlock9: UnsafeMutableRawPointer
    var fastBlock10: UnsafeMutableRawPointer

    // Note: _fastBlock will leak because structs in swift do not have deinit!
    public init(_ actor: Actor, _ block: @escaping BehaviorBlock) {
        self.actor = actor
        self.block = block
        self.fastBlock0 = pony_register_fast_block0({ () in block([]) })
        self.fastBlock1 = pony_register_fast_block1({ (arg0) in block([arg0!]) })
        self.fastBlock2 = pony_register_fast_block2({ (arg0, arg1) in block([arg0!, arg1!]) })
        self.fastBlock3 = pony_register_fast_block3({ (arg0, arg1, arg2) in block([arg0!, arg1!, arg2!]) })
        self.fastBlock4 = pony_register_fast_block4({ (arg0, arg1, arg2, arg3) in block([arg0!, arg1!, arg2!, arg3!]) })
        self.fastBlock5 = pony_register_fast_block5({ (arg0, arg1, arg2, arg3, arg4) in block([arg0!, arg1!, arg2!, arg3!, arg4!]) })
        self.fastBlock6 = pony_register_fast_block6({ (arg0, arg1, arg2, arg3, arg4, arg5) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!]) })
        self.fastBlock7 = pony_register_fast_block7({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!]) })
        self.fastBlock8 = pony_register_fast_block8({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!]) })
        self.fastBlock9 = pony_register_fast_block9({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!]) })
        self.fastBlock10 = pony_register_fast_block10({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!, arg9!]) })
    }

    public func dynamicallyCall(withArguments args: BehaviorArgs) {
        switch args.count {
        case 1: pony_actor_fast_dispatch1(actor.ponyActor, args[0], fastBlock1)
        case 2: pony_actor_fast_dispatch2(actor.ponyActor, args[0], args[1], fastBlock2)
        case 3: pony_actor_fast_dispatch3(actor.ponyActor, args[0], args[1], args[2], fastBlock3)
        case 4: pony_actor_fast_dispatch4(actor.ponyActor, args[0], args[1], args[2], args[3], fastBlock4)
        case 5: pony_actor_fast_dispatch5(actor.ponyActor, args[0], args[1], args[2], args[3], args[4], fastBlock5)
        case 6: pony_actor_fast_dispatch6(actor.ponyActor, args[0], args[1], args[2], args[3], args[4], args[5], fastBlock6)
        case 7: pony_actor_fast_dispatch7(actor.ponyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], fastBlock7)
        case 8: pony_actor_fast_dispatch8(actor.ponyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], fastBlock8)
        case 9: pony_actor_fast_dispatch9(actor.ponyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], fastBlock9)
        case 10: pony_actor_fast_dispatch10(actor.ponyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], fastBlock10)
        default: pony_actor_fast_dispatch0(actor.ponyActor, fastBlock0)
        }
    }
}
