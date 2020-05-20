//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import Flynn.Pony

public typealias ActorBlock = (() -> Void)

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
    
    internal static var pony_is_started:Bool = false
    
    open class func startup() {
        pony_startup()
        pony_is_started = true
    }
    
    open class func shutdown() {
        pony_shutdown()
        pony_is_started = false
    }
    
    internal let _uuid:String
    
    internal var _num_targets:Int = 0
    internal var _target:Actor?
    internal var _targets:[Actor]
    internal var _pony_actor_targets:[UnsafeMutableRawPointer]
    internal let _pony_actor:UnsafeMutableRawPointer
    
    internal var _poolIdx:Int = 0
            
    func chainProcess(args:BehaviorArgs) -> (Bool,BehaviorArgs) {
        // overridden by subclasses to handle processing chained requests
        return (true,args)
    }
    
    // MARK: - Behaviors
    private func sharedChain(_ args:BehaviorArgs) {
        let (should_chain,new_args) = chainProcess(args: args)
        if should_chain {
            let num_targets = _num_targets
            switch num_targets {
                case 0:
                    return
                case 1:
                    _target?.chain.dynamicallyCall(withArguments: new_args)
                default:
                    if new_args.isEmpty {
                        var pony_actors = _pony_actor_targets
                        // If we're sending the "end of chain" item, and we have more than one target, then we
                        // need to delay sending this item until all of the targets have finished processing
                        // all of their messages.  Otherwise we can have a race condition.
                        pony_actors_wait(0, &pony_actors, Int32(num_targets))
                    }
                    
                    _poolIdx = (_poolIdx + 1) % num_targets
                    _targets[_poolIdx].chain.dynamicallyCall(withArguments: new_args)
            }
        }
    }
    
    lazy var chain = Behavior(self) { (args:BehaviorArgs) in
        self.sharedChain(args)
    }
        
    lazy var target = Behavior(self) { (args:BehaviorArgs) in
        let local_target:Actor = args[x:0]
        self._target = local_target
        self._targets.append(local_target)
        self._pony_actor_targets.append(local_target._pony_actor)
        self._num_targets = self._targets.count
    }
    
    lazy var targets = Behavior(self) { (args:BehaviorArgs) in
        let local_targets:[Actor] = args[x:0]
        self._target = local_targets.first
        self._targets.append(contentsOf: local_targets)
        for target in local_targets {
            self._pony_actor_targets.append(target._pony_actor)
        }
        self._num_targets = self._targets.count
    }
    
    
    // MARK: - Functions
    func wait(_ min_msgs:Int32) {
        // Pause while waiting for this actor's message queue to reach 0
        var my_pony_actor = _pony_actor
        pony_actors_wait(min_msgs, &my_pony_actor, 1)
    }
    
    // While not 100% accurate, it can be helpful to know how large the
    // actor's mailbox size is in order to perform lite load balancing
    var messagesCount:Int32 {
        get {
            return pony_actor_num_messages(_pony_actor)
        }
    }
                
    public init() {
        if Actor.pony_is_started == false {
            Actor.startup()
        }
        
        _pony_actor = pony_actor_create()
        
        _uuid = UUID().uuidString
        _target = nil
        _targets = []
        _pony_actor_targets = []
    }
    
    deinit {
        pony_actor_destroy(_pony_actor)
    }
}

