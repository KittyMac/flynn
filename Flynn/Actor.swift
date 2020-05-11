//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
/*
infix operator | : MultiplicationPrecedence
public func | (lhs:Actor, rhs:Actor) -> Actor {
    return rhs
}*/

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
    
    func chainProcess(args:BehaviorArgs) -> BehaviorArgs {
        // overridden by subclasses to handle processing chained requests
        print("Actor:chainProcess")
        return args
    }
    
    lazy var chain = Behavior(self) { (args:BehaviorArgs) in
        // This is called when from another actor wanting to pass us data in a generic manner
        // We need to process the data, then pass it on to the next actor in the chain.
        self._messages.addOperation {
            let new_args = self.chainProcess(args: args)
            self._target?.chainCall(withKeywordArguments: new_args)
        }
    }
    
    
    // While not 100% accurate, it can be helpful to know how large the
    // actor's mailbox size is in order to perform lite load balancing
    var messagesCount:Int {
        get {
            return _messages.operationCount
        }
    }
    
    func target(_ target:Actor) -> Actor {
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

