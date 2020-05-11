//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

public typealias BehaviorBlock = ((BehaviorArgs) -> Void)

@dynamicCallable
public struct Behavior<T:Actor> {
    let actor:T!
    let block:BehaviorBlock!
    public init(_ actor:T, _ block:@escaping BehaviorBlock) {
        self.actor = actor
        self.block = block
    }
    @discardableResult public func dynamicallyCall(withKeywordArguments args:BehaviorArgs) -> T {
        actor.messages.async {
            self.block(args)
        }
        return actor
    }
}

open class Actor {
    fileprivate let uuid:String!
    fileprivate let messages:DispatchQueue!
    
    public init() {
        uuid = UUID().uuidString
        messages = DispatchQueue(label: "actor.queue.\(uuid!)")
    }
}

