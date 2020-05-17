//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import Flynn.Pony

func bridge(_ obj : AnyObject) -> UnsafeMutableRawPointer {
    return UnsafeMutableRawPointer(Unmanaged.passRetained(obj).toOpaque())
}

func bridge<T:AnyObject>(_ ptr : UnsafeMutableRawPointer?) -> T? {
    if let ptr = ptr {
        return Unmanaged.fromOpaque(ptr).takeRetainedValue()
    }
    return nil
}

func bridge<T:AnyObject>(_ ptr : UnsafeMutableRawPointer) -> T? {
    return Unmanaged.fromOpaque(ptr).takeRetainedValue()
}

// TODO: switch BehaviorArgs to dynamicallyCall(withArguments:). This has several benefits
// 1. it sends an Array (I think), and not a struct.
// 2. If its an Array, it can be passed to C and back as a pointer without copying
// 3. we know how to do blocks without copying (store in bahavior, store pointer to block, send pointer to block).
// 4. given 1-3, if we do them all we might be able to have fast, copy-less behavior calling!
public typealias BehaviorArgs = [Any]

public extension Array {
    // Extract and convert a subscript all in one command. Since we don't have compiler
    // support for checking parameters with behaviors, I am leaning towards crashing
    // in order to help identify buggy code faster.
    func get<T>(_ idx: Int) -> T {
        return self[idx] as! T
    }
    
    func check(_ idx: Int) -> Any {
        return self[idx]
    }
}



public typealias FastDispatchBlock = (@convention(block) (Any) -> Void )
public typealias BehaviorBlock = ((BehaviorArgs) -> Void)

@dynamicCallable
public struct Behavior<T:Actor> {
    let _actor:T
    let _block:BehaviorBlock
    var _fast_block:UnsafeMutableRawPointer
    
    // Note: _fast_block will leak because structs in swift do not have deinit!
    public init(_ actor:T, _ block:@escaping BehaviorBlock) {
        self._actor = actor
        self._block = block
        self._fast_block = pony_register_fast_block({ (num, arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9) in
            switch(num) {
                case 1: block([arg0!])
                case 2: block([arg0!, arg1!])
                case 3: block([arg0!, arg1!, arg2!])
                case 4: block([arg0!, arg1!, arg2!, arg3!])
                case 5: block([arg0!, arg1!, arg2!, arg3!, arg4!])
                case 6: block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!])
                case 7: block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!])
                case 8: block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!])
                case 9: block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!])
                case 10: block([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!, arg9!])
                default: block([])
            }
            
        })
    }
    
    @discardableResult public func dynamicallyCall(withArguments args:BehaviorArgs) -> T {
        switch(args.count) {
            case 1: pony_actor_fast_dispatch(_actor._pony_actor, 1, args[0], nil, nil, nil, nil, nil, nil, nil, nil, nil, _fast_block)
            case 2: pony_actor_fast_dispatch(_actor._pony_actor, 2, args[0], args[1], nil, nil, nil, nil, nil, nil, nil, nil, _fast_block)
            case 3: pony_actor_fast_dispatch(_actor._pony_actor, 3, args[0], args[1], args[2], nil, nil, nil, nil, nil, nil, nil, _fast_block)
            case 4: pony_actor_fast_dispatch(_actor._pony_actor, 4, args[0], args[1], args[2], args[3], nil, nil, nil, nil, nil, nil, _fast_block)
            case 5: pony_actor_fast_dispatch(_actor._pony_actor, 5, args[0], args[1], args[2], args[3], args[4], nil, nil, nil, nil, nil, _fast_block)
            case 6: pony_actor_fast_dispatch(_actor._pony_actor, 6, args[0], args[1], args[2], args[3], args[4], args[5], nil, nil, nil, nil, _fast_block)
            case 7: pony_actor_fast_dispatch(_actor._pony_actor, 7, args[0], args[1], args[2], args[3], args[4], args[5], args[6], nil, nil, nil, _fast_block)
            case 8: pony_actor_fast_dispatch(_actor._pony_actor, 8, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], nil, nil, _fast_block)
            case 9: pony_actor_fast_dispatch(_actor._pony_actor, 9, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], nil, _fast_block)
            case 10: pony_actor_fast_dispatch(_actor._pony_actor, 10, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], _fast_block)
            default: pony_actor_fast_dispatch(_actor._pony_actor, 0, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, _fast_block)
        }
        
        return _actor
    }
}
