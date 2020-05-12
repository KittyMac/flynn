//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import Flynn.Pony

infix operator |> : AssignmentPrecedence
public func |> (left: Actor, right: Actor) -> Actor {
    left.target(right)
    return left
}
public func |> (left: Actor, right: [Actor]) -> Actor {
    left.targets(right)
    return left
}
public func |> (left: [Actor], right: Actor) -> [Actor] {
    for one in left {
        one.target(right)
    }
    return left
}

open class Actor {
        
    internal let _uuid:String!
    internal let _messages:DispatchQueue!
    internal var _targets:[Actor]
    internal var _waitingMessages:Int = 0
    
    internal func send(_ block: @escaping () -> Void) {
        _waitingMessages += 1
        _messages.async() {
            block()
            self._waitingMessages -= 1
        }
    }
    
    internal func chainCall(withKeywordArguments args:BehaviorArgs) {
        chain.dynamicallyCall(withKeywordArguments: args)
    }
        
    func chainProcess(args:BehaviorArgs) -> (Bool,BehaviorArgs) {
        // overridden by subclasses to handle processing chained requests
        return (true,args)
    }
    
    lazy var chain = Behavior(self) { (args:BehaviorArgs) in
        // This is called when from another actor wanting to pass us data in a generic manner
        // We need to process the data, then pass it on to the next actor in the chain.
        self.send {
            let (should_chain,new_args) = self.chainProcess(args: args)
            if should_chain {
                switch self._targets.count {
                case 0:
                    return
                case 1:
                    self._targets.first?.chainCall(withKeywordArguments: new_args)
                default:
                    if args.count == 0 {
                        // If we're sending the "end of chain" item, and we have more than one target, then we
                        // need to delay sending this item until all of the targets have finished processing
                        // all of their messages.  Otherwise we can have a race condition.
                        while true {
                            var num:Int = 0;
                            for target in self._targets {
                                num += target.messagesCount
                            }
                            if num == 0 {
                                break
                            }
                            usleep(1000)
                        }
                        
                    }
                    
                    // automatic load balancing, find the target with the least amout of work queued up
                    let minTarget = self._targets.min { a, b in a.messagesCount < b.messagesCount }
                    minTarget?.chainCall(withKeywordArguments: new_args)
                }
            }
        }
    }
    
    
    // While not 100% accurate, it can be helpful to know how large the
    // actor's mailbox size is in order to perform lite load balancing
    var messagesCount:Int {
        get {
            return _waitingMessages
        }
    }
    
    @discardableResult func target(_ target:Actor) -> Actor {
        send {
            self._targets.append(target)
        }
        return self
    }
    
    @discardableResult func targets(_ targets:[Actor]) -> Actor {
        send {
            self._targets.append(contentsOf: targets)
        }
        return self
    }
        
    public init() {
        pony_init()
        
        _uuid = UUID().uuidString
        _messages = DispatchQueue(label: "actor." + _uuid + ".queue")
        _targets = []
    }
}

