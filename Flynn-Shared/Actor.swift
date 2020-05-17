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
    
    internal func _fast_chain_shared(_ args:BehaviorArgs) {
        let (should_chain,new_args) = chainProcess(args: args)
        if should_chain {
            let num_targets = _num_targets
            switch num_targets {
            case 0:
                return
            case 1:
                _target?.chainCall(withArguments: new_args)
            default:
                if new_args.isEmpty {
                    var pony_actors = _pony_actor_targets
                    // If we're sending the "end of chain" item, and we have more than one target, then we
                    // need to delay sending this item until all of the targets have finished processing
                    // all of their messages.  Otherwise we can have a race condition.
                    pony_actors_wait(0, &pony_actors, Int32(num_targets))
                }
                
                switch _loadBalance {
                case .Minimum:
                    // automatic load balancing, find the target with the least amout of work queued up
                    var pony_actors = _pony_actor_targets
                    let minIdx = Int(pony_actors_load_balance(&pony_actors, Int32(num_targets)))
                    let minTarget = _targets[minIdx]
                    minTarget.chainCall(withArguments: new_args)
                    break
                case .Random:
                    if let target = _targets.randomElement() {
                        target.chainCall(withArguments: new_args)
                    } else {
                        let minTarget = _targets[0]
                        minTarget.chainCall(withArguments: new_args)
                    }
                    break
                case .RoundRobin:
                    _poolIdx = (_poolIdx + 1) % num_targets
                    let minTarget = _targets[_poolIdx]
                    minTarget.chainCall(withArguments: new_args)
                    break
                }
            }
        }
    }
    
    internal lazy var _fast_chain_block0:UnsafeMutableRawPointer = pony_register_fast_block0({ () in
        self._fast_chain_shared([])
    })
    internal lazy var _fast_chain_block1:UnsafeMutableRawPointer = pony_register_fast_block1({ (arg0) in
        self._fast_chain_shared([arg0!])
    })
    internal lazy var _fast_chain_block2:UnsafeMutableRawPointer = pony_register_fast_block2({ (arg0, arg1) in
        self._fast_chain_shared([arg0!, arg1!])
    })
    internal lazy var _fast_chain_block3:UnsafeMutableRawPointer = pony_register_fast_block3({ (arg0, arg1, arg2) in
        self._fast_chain_shared([arg0!, arg1!, arg2!])
    })
    internal lazy var _fast_chain_block4:UnsafeMutableRawPointer = pony_register_fast_block4({ (arg0, arg1, arg2, arg3) in
        self._fast_chain_shared([arg0!, arg1!, arg2!, arg3!])
    })
    internal lazy var _fast_chain_block5:UnsafeMutableRawPointer = pony_register_fast_block5({ (arg0, arg1, arg2, arg3, arg4) in
        self._fast_chain_shared([arg0!, arg1!, arg2!, arg3!, arg4!])
    })
    internal lazy var _fast_chain_block6:UnsafeMutableRawPointer = pony_register_fast_block6({ (arg0, arg1, arg2, arg3, arg4, arg5) in
        self._fast_chain_shared([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!])
    })
    internal lazy var _fast_chain_block7:UnsafeMutableRawPointer = pony_register_fast_block7({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6) in
        self._fast_chain_shared([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!])
    })
    internal lazy var _fast_chain_block8:UnsafeMutableRawPointer = pony_register_fast_block8({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7) in
        self._fast_chain_shared([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!])
    })
    internal lazy var _fast_chain_block9:UnsafeMutableRawPointer = pony_register_fast_block9({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8) in
        self._fast_chain_shared([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!])
    })
    internal lazy var _fast_chain_block10:UnsafeMutableRawPointer = pony_register_fast_block10({ (arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9) in
        self._fast_chain_shared([arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!, arg9!])
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
            case 1: pony_actor_fast_dispatch1(self._pony_actor, args[0], self._fast_chain_block1)
            case 2: pony_actor_fast_dispatch2(self._pony_actor, args[0], args[1], self._fast_chain_block2)
            case 3: pony_actor_fast_dispatch3(self._pony_actor, args[0], args[1], args[2], self._fast_chain_block3)
            case 4: pony_actor_fast_dispatch4(self._pony_actor, args[0], args[1], args[2], args[3], self._fast_chain_block4)
            case 5: pony_actor_fast_dispatch5(self._pony_actor, args[0], args[1], args[2], args[3], args[4], self._fast_chain_block5)
            case 6: pony_actor_fast_dispatch6(self._pony_actor, args[0], args[1], args[2], args[3], args[4], args[5], self._fast_chain_block6)
            case 7: pony_actor_fast_dispatch7(self._pony_actor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], self._fast_chain_block7)
            case 8: pony_actor_fast_dispatch8(self._pony_actor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], self._fast_chain_block8)
            case 9: pony_actor_fast_dispatch9(self._pony_actor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], self._fast_chain_block9)
            case 10: pony_actor_fast_dispatch10(self._pony_actor, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], self._fast_chain_block10)
            default: pony_actor_fast_dispatch0(self._pony_actor, self._fast_chain_block0)
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
    
    internal func argsToBehaviorArgs(_ arg0:Any?, _ arg1:Any?, _ arg2:Any?, _ arg3:Any?, _ arg4:Any?, _ arg5:Any?, _ arg6:Any?, _ arg7:Any?, _ arg8:Any?, _ arg9:Any?) -> BehaviorArgs {
        if arg9 != nil {    return [arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!, arg9!]    }
        if arg8 != nil {    return [arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!, arg8!]    }
        if arg7 != nil {    return [arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!, arg7!]    }
        if arg6 != nil {    return [arg0!, arg1!, arg2!, arg3!, arg4!, arg5!, arg6!]    }
        if arg5 != nil {    return [arg0!, arg1!, arg2!, arg3!, arg4!, arg5!]    }
        if arg4 != nil {    return [arg0!, arg1!, arg2!, arg3!, arg4!]    }
        if arg3 != nil {    return [arg0!, arg1!, arg2!, arg3!]    }
        if arg2 != nil {    return [arg0!, arg1!, arg2!]    }
        if arg1 != nil {    return [arg0!, arg1!]    }
        if arg0 != nil {    return [arg0!]    }
        return []
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

