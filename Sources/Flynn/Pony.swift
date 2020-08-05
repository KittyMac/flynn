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
        msg.block([])
    }
}

enum Pony {
    
    class PonyActorMessage0 {
        let block: BehaviorBlock
        
        init(_ block: @escaping BehaviorBlock) {
            self.block = block
        }
    }
        
    struct PonyActor {
        let actorPtr: AnyPtr
        
        init() {
            actorPtr = pony_actor_create()
        }
        
        func attach(_ actor: Actor) {
            pony_actor_attach_swift_actor(actorPtr, Ptr(actor))
        }
        
        func send(_ block: @escaping BehaviorBlock, _ args: BehaviorArgs) {
            let msg = PonyActorMessage0(block)
            pony_actor_send_message(actorPtr, Ptr(msg), handleMessage0)
        }
        
        var messageCount: Int32 {
            return pony_actor_num_messages(actorPtr)
        }
    }
    
}
