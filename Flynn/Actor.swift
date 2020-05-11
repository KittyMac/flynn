//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

infix operator |> : AssignmentPrecedence
public func |> (left: Actor, right: Actor) -> Actor {
    left.target(right)
    return left
}

open class Actor {
    internal let _uuid:String!
    internal let _messages:OperationQueue!
    internal var _target:Actor?
    
    internal func send(_ block: @escaping () -> Void) {
        _messages.addOperation(block)
    }
    
    internal func chainCall(withKeywordArguments args:BehaviorArgs) {
        chain.dynamicallyCall(withKeywordArguments: args)
    }
    
    func chainEnd(args:BehaviorArgs) -> BehaviorArgs {
        // overridden by subclasses to handle the end of a processing chain
        print("Actor:chainEnd")
        return args
    }
    
    func chainProcess(args:BehaviorArgs) -> (Bool,BehaviorArgs) {
        // overridden by subclasses to handle processing chained requests
        return (true,args)
    }
    
    lazy var chain = Behavior(self) { (args:BehaviorArgs) in
        // This is called when from another actor wanting to pass us data in a generic manner
        // We need to process the data, then pass it on to the next actor in the chain.
        self._messages.addOperation {
            let (should_chain,new_args) = self.chainProcess(args: args)
            if should_chain {
                self._target?.chainCall(withKeywordArguments: new_args)
            }
        }
    }
    
    
    // While not 100% accurate, it can be helpful to know how large the
    // actor's mailbox size is in order to perform lite load balancing
    var messagesCount:Int {
        get {
            return _messages.operationCount
        }
    }
    
    @discardableResult func target(_ target:Actor) -> Actor {
        _messages.addOperation {
            self._target = target
        }
        return self
    }
    
    func yield(_ ms:Int) {
        // stop processing messages for ms number of milliseconds
        _messages.isSuspended = true
        let deadlineTime = DispatchTime.now() + .milliseconds(ms)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
            self._messages.isSuspended = false
        }
    }
    
    public init() {
        _uuid = UUID().uuidString
        _messages = OperationQueue()
        _messages.qualityOfService = .userInteractive
        _messages.maxConcurrentOperationCount = 1
    }
}

