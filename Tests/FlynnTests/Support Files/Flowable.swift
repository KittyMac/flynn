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
    override func protected_flowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
        return (true, args)
    }
}

// Print description of arguments to file
class Print: Actor {
    override func protected_flowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
        print(args.description)
        return (true, args)
    }
}

// Takes a string as the first argument, passes along the uppercased version of it
class Uppercase: Actor {
    override func protected_flowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
        if args.isEmpty == false {
            let value: String = args[x: 0]
            return (true, [value.uppercased()])
        }
        return (true, args)
    }
}

// Takes a string as the first argument, concatenates all strings
// received.  When it receives an empty argument list it considers
// that to be "done", and sends the concatenated string to the target
class Concatenate: Actor {
    var combined: String = ""

    override init() {
        super.init()
        priority = 1
    }

    override func protected_flowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
        if args.isEmpty == false {
            let value: String = args[x: 0]
            combined.append(value)
            return (false, args)
        }
        return (true, [combined])
    }
}

class Callback: Actor {
    let callback: ((BehaviorArgs) -> Void)!

    init(_ callback:@escaping ((BehaviorArgs) -> Void)) {
        self.callback = callback
        super.init()
    }

    override func protected_flowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
        callback(args)
        return (true, args)
    }
}
