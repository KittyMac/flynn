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

#if PLATFORM_SUPPORTS_PONYRT

import Pony

struct FastBlockCalls {
    private var fastBlock0Ptr: UnsafeMutableRawPointer
    private var fastBlock1Ptr: UnsafeMutableRawPointer
    private var fastBlock2Ptr: UnsafeMutableRawPointer
    private var fastBlock3Ptr: UnsafeMutableRawPointer
    private var fastBlock4Ptr: UnsafeMutableRawPointer
    private var fastBlock5Ptr: UnsafeMutableRawPointer
    private var fastBlock6Ptr: UnsafeMutableRawPointer
    private var fastBlock7Ptr: UnsafeMutableRawPointer
    private var fastBlock8Ptr: UnsafeMutableRawPointer
    private var fastBlock9Ptr: UnsafeMutableRawPointer
    private var fastBlock10Ptr: UnsafeMutableRawPointer

    private var fastBlock0: FastBlockCallback0
    private var fastBlock1: FastBlockCallback1
    private var fastBlock2: FastBlockCallback2
    private var fastBlock3: FastBlockCallback3
    private var fastBlock4: FastBlockCallback4
    private var fastBlock5: FastBlockCallback5
    private var fastBlock6: FastBlockCallback6
    private var fastBlock7: FastBlockCallback7
    private var fastBlock8: FastBlockCallback8
    private var fastBlock9: FastBlockCallback9
    private var fastBlock10: FastBlockCallback10

    init(_ block: @escaping BehaviorBlock) {
        fastBlock0 = { () in block([]) }
        fastBlock1 = { (arg0) in block([arg0!]) }
        fastBlock2 = { (arg0, arg1) in block([arg0!, arg1!]) }
        fastBlock3 = { (arg0, arg1, arg2) in block([arg0!, arg1!, arg2!]) }
        fastBlock4 = { (arg0, arg1, arg2, arg3) in block([arg0!, arg1!, arg2!, arg3!]) }
        fastBlock5 = { (arg0, arg1, arg2, arg3, arg4) in block([arg0!, arg1!, arg2!, arg3!, arg4!]) }
        fastBlock6 = { (arg0, arg1, arg2, arg3, arg4, arg5) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!]) }
        fastBlock7 = { (arg0, arg1, arg2, arg3, arg4, arg5, arg6) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!]) }
        fastBlock8 = { (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!]) }
        fastBlock9 = { (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!]) }
        fastBlock10 = { (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!, arg9!]) }

        fastBlock0Ptr = pony_register_fast_block0(fastBlock0)
        fastBlock1Ptr = pony_register_fast_block1(fastBlock1)
        fastBlock2Ptr = pony_register_fast_block2(fastBlock2)
        fastBlock3Ptr = pony_register_fast_block3(fastBlock3)
        fastBlock4Ptr = pony_register_fast_block4(fastBlock4)
        fastBlock5Ptr = pony_register_fast_block5(fastBlock5)
        fastBlock6Ptr = pony_register_fast_block6(fastBlock6)
        fastBlock7Ptr = pony_register_fast_block7(fastBlock7)
        fastBlock8Ptr = pony_register_fast_block8(fastBlock8)
        fastBlock9Ptr = pony_register_fast_block9(fastBlock9)
        fastBlock10Ptr = pony_register_fast_block10(fastBlock10)
    }

    func dealloc() {
        pony_unregister_fast_block(fastBlock0Ptr)
        pony_unregister_fast_block(fastBlock1Ptr)
        pony_unregister_fast_block(fastBlock2Ptr)
        pony_unregister_fast_block(fastBlock3Ptr)
        pony_unregister_fast_block(fastBlock4Ptr)
        pony_unregister_fast_block(fastBlock5Ptr)
        pony_unregister_fast_block(fastBlock6Ptr)
        pony_unregister_fast_block(fastBlock7Ptr)
        pony_unregister_fast_block(fastBlock8Ptr)
        pony_unregister_fast_block(fastBlock9Ptr)
        pony_unregister_fast_block(fastBlock10Ptr)
    }

    func call(_ actor: Actor, _ args: BehaviorArgs) {
        switch args.count {
        case 1: pony_actor_fast_dispatch1(actor.unsafePonyActor, args[0], fastBlock1Ptr)
        case 2: pony_actor_fast_dispatch2(actor.unsafePonyActor, args[0], args[1], fastBlock2Ptr)
        case 3: pony_actor_fast_dispatch3(actor.unsafePonyActor, args[0], args[1], args[2], fastBlock3Ptr)
        case 4: pony_actor_fast_dispatch4(actor.unsafePonyActor, args[0], args[1], args[2], args[3], fastBlock4Ptr)
        case 5: pony_actor_fast_dispatch5(actor.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], fastBlock5Ptr)
        case 6: pony_actor_fast_dispatch6(actor.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], fastBlock6Ptr)
        case 7: pony_actor_fast_dispatch7(actor.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], fastBlock7Ptr)
        case 8: pony_actor_fast_dispatch8(actor.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], fastBlock8Ptr)
        case 9: pony_actor_fast_dispatch9(actor.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], fastBlock9Ptr)
        case 10: pony_actor_fast_dispatch10(actor.unsafePonyActor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], fastBlock10Ptr)
        default: pony_actor_fast_dispatch0(actor.unsafePonyActor, fastBlock0Ptr)
        }
    }
}

#else

struct FastBlockCalls {
    let block: BehaviorBlock

    init(_ block: @escaping BehaviorBlock) {
        self.block = block
    }

    func dealloc() { }

    func call(_ actor: Actor, _ args: BehaviorArgs) {
        actor.unsafeRetain()

        // TODO: find a non-locking solution for this
        actor.unsafeLock.lock()
        actor.unsafeMsgCount += 1
        actor.unsafeLock.unlock()

        actor.unsafeDispatchQueue.async {
            self.block(args)

            actor.unsafeLock.lock()
            actor.unsafeMsgCount -= 1
            actor.unsafeLock.unlock()

            actor.unsafeRelease()
        }
    }
}

#endif
