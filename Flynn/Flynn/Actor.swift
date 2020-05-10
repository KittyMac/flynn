//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

typealias BehaviorArgs = KeyValuePairs<String, Any>
typealias BehaviorBlock = ((BehaviorArgs) -> Void)

@dynamicCallable
struct Behavior {
    let actor:Actor!
    let block:BehaviorBlock!
    init(_ actor:Actor, _ block:@escaping BehaviorBlock) {
        self.actor = actor
        self.block = block
    }
    func dynamicallyCall(withKeywordArguments args:BehaviorArgs) -> Void {
        actor.messages.async {
            self.block(args)
        }
    }
}

public class Actor {
    fileprivate let uuid:String!
    fileprivate let messages:DispatchQueue!
    
    init() {
        uuid = UUID().uuidString
        messages = DispatchQueue(label: "actor.queue.\(uuid!)")
    }
    
    
    // Every exposed "function" on an actor MUST wrap its contents in
    // a call to messages.async.  TODO: How do we enfore this?
    /* Example:
     private func behavior(_ b:ActorBehavior) {
         messages.async {
             
         }
     }
     */
}

