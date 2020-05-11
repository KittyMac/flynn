//
//  FlynnTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import XCTest

@testable import Flynn

// Pass through all arguments
class Passthrough: Actor {
    override func chainProcess(args:BehaviorArgs) -> (Bool,BehaviorArgs) {
        return (true,args)
    }
}

// Print description of arguments to file
class Print: Actor {
    override func chainProcess(args:BehaviorArgs) -> (Bool,BehaviorArgs) {
        print(args.description)
        return (true,args)
    }
}

// Takes a string as the first argument, passes along the uppercased version of it
class Uppercase: Actor {
    override func chainProcess(args:BehaviorArgs) -> (Bool,BehaviorArgs) {
        if args.count > 0 {
            let s:String = args[0]
            return (true,["": s.uppercased()])
        }
        return (true,args)
    }
}

// Takes a string as the first argument, concatenates all strings
// received.  When it receives ChainEnd as the first argument, it
// then sends along the entire string
class Concatenate: Actor {
    var combined:String = ""
    override func chainProcess(args:BehaviorArgs) -> (Bool,BehaviorArgs) {
        if args.count > 0 {
            let s:String = args[0]
            combined.append(s)
            return (false,args)
        }
        return (true,["": combined])
    }
}

class Callback: Actor {
    let _callback:((BehaviorArgs) -> Void)!
    
    init(_ callback:@escaping ((BehaviorArgs) -> Void)) {
        _callback = callback
        super.init()
    }
    
    override func chainProcess(args:BehaviorArgs) -> (Bool,BehaviorArgs) {
        _callback(args)
        return (true,args)
    }
}

