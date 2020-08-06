//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import Pony

typealias AnyPtr = UnsafeMutableRawPointer?

func Ptr <T: AnyObject>(_ obj: T) -> AnyPtr {
    return Unmanaged.passRetained(obj).toOpaque()
}

func Class <T: AnyObject>(_ ptr: AnyPtr) -> T? {
    guard let ptr = ptr else { return nil }
    return Unmanaged<T>.fromOpaque(ptr).takeRetainedValue()
}

let emptyArgs: BehaviorArgs = []

fileprivate func handleMessage0(_ argumentPtr: AnyPtr) {
    if let msg: Pony.PonyActorMessage0 = Class(argumentPtr) {
        msg.run()
    }
}

fileprivate func handleMessage1(_ argumentPtr: AnyPtr) {
    if let msg: Pony.PonyActorMessage1 = Class(argumentPtr) {
        msg.run()
    }
}

fileprivate func handleMessageMany(_ argumentPtr: AnyPtr) {
    if let msg: Pony.PonyActorMessageMany = Class(argumentPtr) {
        msg.run()
    }
}

enum Pony {
    
    class PonyActorMessage0 {
        weak var pool: Queue<PonyActorMessage0>?
        var block: BehaviorBlock?
        
        init(_ pool:Queue<PonyActorMessage0>?, _ block: @escaping BehaviorBlock) {
            self.pool = pool
            self.block = block
        }
        
        func set(_ block: @escaping BehaviorBlock) {
            self.block = block
        }
        
        func run() {
            block?(emptyArgs)
            block = nil
            pool?.enqueue(self)
        }
    }
    
    class PonyActorMessage1 {
        weak var pool: Queue<PonyActorMessage1>?
        var block: BehaviorBlock?
        var arg: Any?
        
        init(_ pool: Queue<PonyActorMessage1>?, _ block: @escaping BehaviorBlock, _ arg: Any?) {
            self.pool = pool
            self.block = block
            self.arg = arg
        }
        
        func set(_ block: @escaping BehaviorBlock, _ arg: Any?) {
            self.block = block
            self.arg = arg
        }
        
        func run() {
            block?([arg])
            block = nil
            arg = nil
            pool?.enqueue(self)
        }
    }
    
    class PonyActorMessageMany {
        weak var pool: Queue<PonyActorMessageMany>?
        var block: BehaviorBlock?
        var args: BehaviorArgs?
        
        init(_ pool: Queue<PonyActorMessageMany>?, _ block: @escaping BehaviorBlock, _ args: BehaviorArgs) {
            self.block = block
            self.args = args
        }
        
        func set(_ block: @escaping BehaviorBlock, _ args: BehaviorArgs) {
            self.block = block
            self.args = args
        }
        
        func run() {
            block?(args!)
            block = nil
            args = nil
            pool?.enqueue(self)
        }
    }
        
    struct PonyActor {
        let actorPtr: AnyPtr
        
        var poolMessage0 = Queue<PonyActorMessage0>(size: 128, manyProducers: false, manyConsumers: true)
        var poolMessage1 = Queue<PonyActorMessage1>(size: 128, manyProducers: false, manyConsumers: true)
        var poolMessageMany = Queue<PonyActorMessageMany>(size: 128, manyProducers: false, manyConsumers: true)
        
        init() {
            actorPtr = pony_actor_create()
        }
        
        func attach(_ actor: Actor) {
            pony_actor_attach_swift_actor(actorPtr, Ptr(actor))
        }
        
        private func unpoolMessage0(_ block: @escaping BehaviorBlock) -> PonyActorMessage0 {
            if let msg = poolMessage0.dequeue() {
                msg.set(block)
                return msg
            }
            return PonyActorMessage0(poolMessage0, block)
        }
        
        private func unpoolMessage1(_ block: @escaping BehaviorBlock, _ arg: Any?) -> PonyActorMessage1 {
            if let msg = poolMessage1.dequeue() {
                msg.set(block, arg)
                return msg
            }
            return PonyActorMessage1(poolMessage1, block, arg)
        }
        
        private func unpoolMessageMany(_ block: @escaping BehaviorBlock, _ args: BehaviorArgs) -> PonyActorMessageMany {
            if let msg = poolMessageMany.dequeue() {
                msg.set(block, args)
                return msg
            }
            return PonyActorMessageMany(poolMessageMany, block, args)
        }
        
        func send(_ block: @escaping BehaviorBlock, _ args: BehaviorArgs) {
            switch args.count {
            case 0:
                pony_actor_send_message(actorPtr, Ptr(unpoolMessage0(block)), handleMessage0)
            case 1:
                pony_actor_send_message(actorPtr, Ptr(unpoolMessage1(block, args[0])), handleMessage1)
            default:
                pony_actor_send_message(actorPtr, Ptr(unpoolMessageMany(block, args)), handleMessageMany)
            }
            
        }
        
        var messageCount: Int32 {
            return pony_actor_num_messages(actorPtr)
        }
    }
    
}
