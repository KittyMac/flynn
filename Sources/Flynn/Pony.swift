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

fileprivate func handleMessage0(_ argumentPtr: AnyPtr) {
    if let msg: Pony.PonyActorMessage0 = Class(argumentPtr) {
        msg.run()
    }
}

typealias NewBehaviorBlock = () -> Void

enum Pony {
    
    class PonyActorMessage0 {
        weak var pool: Queue<PonyActorMessage0>?
        var block: NewBehaviorBlock?
        
        init(_ pool:Queue<PonyActorMessage0>?, _ block: @escaping NewBehaviorBlock) {
            self.pool = pool
            self.block = block
        }
        
        func set(_ block: @escaping NewBehaviorBlock) {
            self.block = block
        }
        
        func run() {
            block?()
            block = nil
            pool?.enqueue(self)
        }
    }
        
    struct PonyActor {
        let actorPtr: AnyPtr
        
        var poolMessage0 = Queue<PonyActorMessage0>(size: 128, manyProducers: false, manyConsumers: true)
        
        init() {
            actorPtr = pony_actor_create()
        }
        
        func attach(_ actor: Actor) {
            pony_actor_attach_swift_actor(actorPtr, Ptr(actor))
        }
        
        private func unpoolMessage0(_ block: @escaping NewBehaviorBlock) -> PonyActorMessage0 {
            if let msg = poolMessage0.dequeue() {
                msg.set(block)
                return msg
            }
            return PonyActorMessage0(poolMessage0, block)
        }
                
        func send(_ block: @escaping BehaviorBlock, _ args: BehaviorArgs) {
            send({ block(args) })
        }
        
        func send(_ block: @escaping NewBehaviorBlock) {
            pony_actor_send_message(actorPtr, Ptr(unpoolMessage0(block)), handleMessage0)
        }
        
        var messageCount: Int32 {
            return pony_actor_num_messages(actorPtr)
        }
    }
    
}
