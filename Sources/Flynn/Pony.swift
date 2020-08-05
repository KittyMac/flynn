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

fileprivate func handleMessage1(_ argumentPtr: AnyPtr) {
    if let msg: Pony.PonyActorMessage1 = Class(argumentPtr) {
        msg.block([msg.arg])
    }
}

fileprivate func handleMessageMany(_ argumentPtr: AnyPtr) {
    if let msg: Pony.PonyActorMessageMany = Class(argumentPtr) {
        msg.block(msg.args)
    }
}

enum Pony {
    
    class PonyActorMessage0 {
        let block: BehaviorBlock
        
        init(_ block: @escaping BehaviorBlock) {
            self.block = block
        }
    }
    
    class PonyActorMessage1 {
        let block: BehaviorBlock
        let arg: Any?
        
        init(_ block: @escaping BehaviorBlock, _ arg: Any?) {
            self.block = block
            self.arg = arg
        }
    }
    
    class PonyActorMessageMany {
        let block: BehaviorBlock
        let args: BehaviorArgs
        
        init(_ block: @escaping BehaviorBlock, _ args: BehaviorArgs) {
            self.block = block
            self.args = args
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
            switch args.count {
            case 0:
                pony_actor_send_message(actorPtr, Ptr(PonyActorMessage0(block)), handleMessage0)
            case 1:
                pony_actor_send_message(actorPtr, Ptr(PonyActorMessage1(block, args[0])), handleMessage1)
            default:
                pony_actor_send_message(actorPtr, Ptr(PonyActorMessageMany(block, args)), handleMessageMany)
            }
            
        }
        
        var messageCount: Int32 {
            return pony_actor_num_messages(actorPtr)
        }
    }
    
}
