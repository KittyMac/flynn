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

enum LoadBalance {
  case Minimum
  case Random
  case RoundRobin
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
    internal var _loadBalance:LoadBalance = .RoundRobin
    
    internal lazy var _fast_chain_block:UnsafeMutableRawPointer = pony_register_fast_block({ (num, arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9) in
        
        let (should_chain,new_args) = self.chainProcess(args: self.argsToBehaviorArgs(num, arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9))
        if should_chain {
            let num_targets = self._num_targets
            switch num_targets {
            case 0:
                return
            case 1:
                self._target?.chainCall(withArguments: new_args)
            default:
                if new_args.isEmpty {
                    var pony_actors = self._pony_actor_targets
                    // If we're sending the "end of chain" item, and we have more than one target, then we
                    // need to delay sending this item until all of the targets have finished processing
                    // all of their messages.  Otherwise we can have a race condition.
                    pony_actors_wait(0, &pony_actors, Int32(num_targets))
                }
                
                switch self._loadBalance {
                case .Minimum:
                    // automatic load balancing, find the target with the least amout of work queued up
                    var pony_actors = self._pony_actor_targets
                    let minIdx = Int(pony_actors_load_balance(&pony_actors, Int32(num_targets)))
                    let minTarget = self._targets[minIdx]
                    minTarget.chainCall(withArguments: new_args)
                    break
                case .Random:
                    if let target = self._targets.randomElement() {
                        target.chainCall(withArguments: new_args)
                    } else {
                        let minTarget = self._targets[0]
                        minTarget.chainCall(withArguments: new_args)
                    }
                    break
                case .RoundRobin:
                    self._poolIdx = (self._poolIdx + 1) % num_targets
                    let minTarget = self._targets[self._poolIdx]
                    minTarget.chainCall(withArguments: new_args)
                    break
                }
            }
        }
    })

    
    internal func send(_ block: @escaping ActorBlock) {
        // we need to be careful here: multiple other threads can
        // call this asynchronously. So we must not access any shared state.
        pony_actor_dispatch(_pony_actor, block)
    }
    
    internal func chainCall(withArguments args:BehaviorArgs) {
        chain.dynamicallyCall(withArguments: args)
    }
        
    func chainProcess(args:BehaviorArgs) -> (Bool,BehaviorArgs) {
        // overridden by subclasses to handle processing chained requests
        return (true,args)
    }
    
    lazy var chain = Behavior(self) { (args:BehaviorArgs) in
        switch(args.count) {
            case 1: pony_actor_fast_dispatch(self._pony_actor, 1, args[0], nil, nil, nil, nil, nil, nil, nil, nil, nil, self._fast_chain_block)
            case 2: pony_actor_fast_dispatch(self._pony_actor, 2, args[0], args[1], nil, nil, nil, nil, nil, nil, nil, nil, self._fast_chain_block)
            case 3: pony_actor_fast_dispatch(self._pony_actor, 3, args[0], args[1], args[2], nil, nil, nil, nil, nil, nil, nil, self._fast_chain_block)
            case 4: pony_actor_fast_dispatch(self._pony_actor, 4, args[0], args[1], args[2], args[3], nil, nil, nil, nil, nil, nil, self._fast_chain_block)
            case 5: pony_actor_fast_dispatch(self._pony_actor, 5, args[0], args[1], args[2], args[3], args[4], nil, nil, nil, nil, nil, self._fast_chain_block)
            case 6: pony_actor_fast_dispatch(self._pony_actor, 6, args[0], args[1], args[2], args[3], args[4], args[5], nil, nil, nil, nil, self._fast_chain_block)
            case 7: pony_actor_fast_dispatch(self._pony_actor, 7, args[0], args[1], args[2], args[3], args[4], args[5], args[6], nil, nil, nil, self._fast_chain_block)
            case 8: pony_actor_fast_dispatch(self._pony_actor, 8, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], nil, nil, self._fast_chain_block)
            case 9: pony_actor_fast_dispatch(self._pony_actor, 9, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], nil, self._fast_chain_block)
            case 10: pony_actor_fast_dispatch(self._pony_actor, 10, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], self._fast_chain_block)
            default: pony_actor_fast_dispatch(self._pony_actor, 0, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, self._fast_chain_block)
        }
    }
    
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
    
    @discardableResult func balanced(_ loadBalance:LoadBalance) -> Actor {
        send {
            self._loadBalance = loadBalance
        }
        return self
    }
    
    @discardableResult func target(_ target:Actor) -> Actor {
        send {
            self._target = target
            self._targets.append(target)
            self._pony_actor_targets.append(target._pony_actor)
            self._num_targets = self._targets.count
        }
        return self
    }
    
    @discardableResult func targets(_ targets:[Actor]) -> Actor {
        send {
            self._target = targets.first
            self._targets.append(contentsOf: targets)
            for target in targets {
                self._pony_actor_targets.append(target._pony_actor)
            }
            self._num_targets = self._targets.count
        }
        return self
    }
    
    internal func argsToBehaviorArgs(_ num:Int32, _ arg0:Any?, _ arg1:Any?, _ arg2:Any?, _ arg3:Any?, _ arg4:Any?, _ arg5:Any?, _ arg6:Any?, _ arg7:Any?, _ arg8:Any?, _ arg9:Any?) -> BehaviorArgs {
        switch(num) {
            case 1: return [arg0!]
            case 2: return [arg0!, arg1!]
            case 3: return [arg0!, arg1!, arg2!]
            case 4: return [arg0!, arg1!, arg2!, arg3!]
            case 5: return [arg0!, arg1!, arg2!, arg3!, arg4!]
            case 6: return [arg0!, arg1!, arg2!, arg3!, arg4!, arg5!]
            case 7: return [arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!]
            case 8: return [arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!]
            case 9: return [arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!]
            case 10: return [arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!, arg9!]
            default: return []
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

