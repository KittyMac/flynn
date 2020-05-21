//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import Flynn.Pony

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



public typealias FastDispatchBlock = (@convention(block) (Any) -> Void )
public typealias BehaviorBlock = ((BehaviorArgs) -> Void)

@dynamicCallable
public struct ChainableBehavior<T:Actor> {
    let _actor:T
    let _block:BehaviorBlock
    var _fast_block0:UnsafeMutableRawPointer
    var _fast_block1:UnsafeMutableRawPointer
    var _fast_block2:UnsafeMutableRawPointer
    var _fast_block3:UnsafeMutableRawPointer
    var _fast_block4:UnsafeMutableRawPointer
    var _fast_block5:UnsafeMutableRawPointer
    var _fast_block6:UnsafeMutableRawPointer
    var _fast_block7:UnsafeMutableRawPointer
    var _fast_block8:UnsafeMutableRawPointer
    var _fast_block9:UnsafeMutableRawPointer
    var _fast_block10:UnsafeMutableRawPointer
    
    // Note: _fast_block will leak because structs in swift do not have deinit!
    public init(_ actor:T, _ block:@escaping BehaviorBlock) {
        self._actor = actor
        self._block = block
        self._fast_block0 = pony_register_fast_block0({ () in block([]) })
        self._fast_block1 = pony_register_fast_block1({ (arg0) in block([arg0!]) })
        self._fast_block2 = pony_register_fast_block2({ (arg0, arg1) in block([arg0!, arg1!]) })
        self._fast_block3 = pony_register_fast_block3({ (arg0, arg1, arg2) in block([arg0!, arg1!, arg2!]) })
        self._fast_block4 = pony_register_fast_block4({ (arg0, arg1, arg2, arg3) in block([arg0!, arg1!, arg2!, arg3!]) })
        self._fast_block5 = pony_register_fast_block5({ (arg0, arg1, arg2, arg3, arg4) in block([arg0!, arg1!, arg2!, arg3!, arg4!]) })
        self._fast_block6 = pony_register_fast_block6({ (arg0, arg1, arg2, arg3, arg4, arg5) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!]) })
        self._fast_block7 = pony_register_fast_block7({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!]) })
        self._fast_block8 = pony_register_fast_block8({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!]) })
        self._fast_block9 = pony_register_fast_block9({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!]) })
        self._fast_block10 = pony_register_fast_block10({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!, arg9!]) })
    }
    
    @discardableResult public func dynamicallyCall(withArguments args:BehaviorArgs) -> T {
        switch(args.count) {
            case 1: pony_actor_fast_dispatch1(_actor._pony_actor, args[0], _fast_block1)
            case 2: pony_actor_fast_dispatch2(_actor._pony_actor, args[0], args[1], _fast_block2)
            case 3: pony_actor_fast_dispatch3(_actor._pony_actor, args[0], args[1], args[2], _fast_block3)
            case 4: pony_actor_fast_dispatch4(_actor._pony_actor, args[0], args[1], args[2], args[3], _fast_block4)
            case 5: pony_actor_fast_dispatch5(_actor._pony_actor, args[0], args[1], args[2], args[3], args[4], _fast_block5)
            case 6: pony_actor_fast_dispatch6(_actor._pony_actor, args[0], args[1], args[2], args[3], args[4], args[5], _fast_block6)
            case 7: pony_actor_fast_dispatch7(_actor._pony_actor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], _fast_block7)
            case 8: pony_actor_fast_dispatch8(_actor._pony_actor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], _fast_block8)
            case 9: pony_actor_fast_dispatch9(_actor._pony_actor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], _fast_block9)
            case 10: pony_actor_fast_dispatch10(_actor._pony_actor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], _fast_block10)
            default: pony_actor_fast_dispatch0(_actor._pony_actor, _fast_block0)
        }
        
        return _actor
    }
}

@dynamicCallable
public struct Behavior {
    let _actor:Actor
    let _block:BehaviorBlock
    var _fast_block0:UnsafeMutableRawPointer
    var _fast_block1:UnsafeMutableRawPointer
    var _fast_block2:UnsafeMutableRawPointer
    var _fast_block3:UnsafeMutableRawPointer
    var _fast_block4:UnsafeMutableRawPointer
    var _fast_block5:UnsafeMutableRawPointer
    var _fast_block6:UnsafeMutableRawPointer
    var _fast_block7:UnsafeMutableRawPointer
    var _fast_block8:UnsafeMutableRawPointer
    var _fast_block9:UnsafeMutableRawPointer
    var _fast_block10:UnsafeMutableRawPointer
    
    // Note: _fast_block will leak because structs in swift do not have deinit!
    public init(_ actor:Actor, _ block:@escaping BehaviorBlock) {
        self._actor = actor
        self._block = block
        self._fast_block0 = pony_register_fast_block0({ () in block([]) })
        self._fast_block1 = pony_register_fast_block1({ (arg0) in block([arg0!]) })
        self._fast_block2 = pony_register_fast_block2({ (arg0, arg1) in block([arg0!, arg1!]) })
        self._fast_block3 = pony_register_fast_block3({ (arg0, arg1, arg2) in block([arg0!, arg1!, arg2!]) })
        self._fast_block4 = pony_register_fast_block4({ (arg0, arg1, arg2, arg3) in block([arg0!, arg1!, arg2!, arg3!]) })
        self._fast_block5 = pony_register_fast_block5({ (arg0, arg1, arg2, arg3, arg4) in block([arg0!, arg1!, arg2!, arg3!, arg4!]) })
        self._fast_block6 = pony_register_fast_block6({ (arg0, arg1, arg2, arg3, arg4, arg5) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!]) })
        self._fast_block7 = pony_register_fast_block7({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!]) })
        self._fast_block8 = pony_register_fast_block8({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!]) })
        self._fast_block9 = pony_register_fast_block9({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!]) })
        self._fast_block10 = pony_register_fast_block10({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9) in block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!, arg9!]) })
    }
    
    public func dynamicallyCall(withArguments args:BehaviorArgs) {
        switch(args.count) {
            case 1: pony_actor_fast_dispatch1(_actor._pony_actor, args[0], _fast_block1)
            case 2: pony_actor_fast_dispatch2(_actor._pony_actor, args[0], args[1], _fast_block2)
            case 3: pony_actor_fast_dispatch3(_actor._pony_actor, args[0], args[1], args[2], _fast_block3)
            case 4: pony_actor_fast_dispatch4(_actor._pony_actor, args[0], args[1], args[2], args[3], _fast_block4)
            case 5: pony_actor_fast_dispatch5(_actor._pony_actor, args[0], args[1], args[2], args[3], args[4], _fast_block5)
            case 6: pony_actor_fast_dispatch6(_actor._pony_actor, args[0], args[1], args[2], args[3], args[4], args[5], _fast_block6)
            case 7: pony_actor_fast_dispatch7(_actor._pony_actor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], _fast_block7)
            case 8: pony_actor_fast_dispatch8(_actor._pony_actor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], _fast_block8)
            case 9: pony_actor_fast_dispatch9(_actor._pony_actor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], _fast_block9)
            case 10: pony_actor_fast_dispatch10(_actor._pony_actor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], _fast_block10)
            default: pony_actor_fast_dispatch0(_actor._pony_actor, _fast_block0)
        }
    }
}
