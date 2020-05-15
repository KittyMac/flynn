//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

public typealias BehaviorArgs = KeyValuePairs<String, Any>

public extension KeyValuePairs {
    // Extract and convert a subscript all in one command. Since we don't have compiler
    // support for checking parameters with behaviors, I am leaning towards crashing
    // in order to help identify buggy code faster.
    subscript<T>(_ idx: Int) -> T {
        return self[idx].value as! T
    }
    
    func check(_ idx: Int) -> Any {
        return self[idx].value
    }
}

public typealias BehaviorBlock = ((BehaviorArgs) -> Void)

@dynamicCallable
public struct Behavior<T:Actor> {
    let _actor:T!
    let _block:BehaviorBlock
    public init(_ actor:T, _ block:@escaping BehaviorBlock) {
        self._actor = actor
        self._block = block
    }
    @discardableResult public func dynamicallyCall(withKeywordArguments args:BehaviorArgs) -> T {
        let local_args = args
        let local_block = _block
        pony_actor_dispatch(_actor._pony_actor, {
            local_block(local_args)
        })
        return _actor
    }
}
