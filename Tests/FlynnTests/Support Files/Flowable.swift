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
    override func safeFlowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
        return (true, args)
    }
}

// Print description of arguments to file
class Print: Actor {
    override func safeFlowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
        print(args.description)
        return (true, args)
    }
}

// Takes a string as the first argument, passes along the uppercased version of it
class Uppercase: Actor {
    override func safeFlowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
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
    private var combined: String = ""

    override init() {
        super.init()
        safePriority = 1
    }

    override func safeFlowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
        if args.isEmpty == false {
            let value: String = args[x: 0]
            combined.append(value)
            return (false, args)
        }
        return (true, [combined])
    }
}

class Callback: Actor {
    private let callback: ((BehaviorArgs) -> Void)!

    init(_ callback:@escaping ((BehaviorArgs) -> Void)) {
        self.callback = callback
        super.init()
    }

    override func safeFlowProcess(args: BehaviorArgs) -> (Bool, BehaviorArgs) {
        callback(args)
        return (true, args)
    }
}
