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

internal class ActorBlockBox {
    let block:ActorBlock
    init(_ block:@escaping ActorBlock) {
        self.block = block
    }
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
    
    internal let _uuid:String!
    
    internal var _num_targets:Int = 0
    internal var _targets:[Actor]
    internal var _pony_actor_targets:[UnsafeMutableRawPointer]
    internal let _pony_actor:UnsafeMutableRawPointer!
    
    internal var _poolIdx:Int = 0
    internal var _loadBalance:LoadBalance = .RoundRobin
    
    internal func send(_ block: @escaping ActorBlock) {
        // we need to be careful here: multiple other threads can
        // call this asynchronously. So we must not access any shared state.
        let box = ActorBlockBox(block)
        pony_actor_dispatch(_pony_actor, bridge(box), { (box2) in
            let thisBox:ActorBlockBox? = bridge(box2)
            thisBox?.block()
        })
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
                let num_targets = self._num_targets
                switch num_targets {
                case 0:
                    return
                case 1:
                    self._targets.first?.chainCall(withKeywordArguments: new_args)
                default:
                    if args.isEmpty {
                        var pony_actors = self._pony_actor_targets
                        // If we're sending the "end of chain" item, and we have more than one target, then we
                        // need to delay sending this item until all of the targets have finished processing
                        // all of their messages.  Otherwise we can have a race condition.
                        pony_actors_wait(&pony_actors, Int32(num_targets))
                    }
                    
                    switch self._loadBalance {
                    case .Minimum:
                        // automatic load balancing, find the target with the least amout of work queued up
                        var pony_actors = self._pony_actor_targets
                        let minIdx = Int(pony_actors_load_balance(&pony_actors, Int32(num_targets)))
                        let minTarget = self._targets[minIdx]
                        minTarget.chainCall(withKeywordArguments: new_args)
                        break
                    case .Random:
                        let target = self._targets.randomElement()
                        target!.chainCall(withKeywordArguments: new_args)
                        break
                    case .RoundRobin:
                        self._poolIdx = (self._poolIdx + 1) % num_targets
                        let minTarget = self._targets[self._poolIdx]
                        minTarget.chainCall(withKeywordArguments: new_args)
                        break
                    }
                }
            }
        }
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
            self._targets.append(target)
            self._pony_actor_targets.append(target._pony_actor)
            self._num_targets = self._targets.count
        }
        return self
    }
    
    @discardableResult func targets(_ targets:[Actor]) -> Actor {
        send {
            self._targets.append(contentsOf: targets)
            for target in targets {
                self._pony_actor_targets.append(target._pony_actor)
            }
            self._num_targets = self._targets.count
        }
        return self
    }
        
    public init() {
        if Actor.pony_is_started == false {
            Actor.startup()
        }
        
        _pony_actor = pony_actor_create()
        
        _uuid = UUID().uuidString
        _targets = []
        _pony_actor_targets = []
    }
    
    deinit {
        pony_actor_destroy(_pony_actor)
    }
}

