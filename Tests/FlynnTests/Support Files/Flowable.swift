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
final class Passthrough: Actor, Flowable {
    lazy var safeFlowable = FlowableState(self)

    lazy var beFlow = Behavior(self) { (args: BehaviorArgs) in
        // flynnlint:parameter Any
        self.safeFlowToNextTarget(args)
    }
}

// Print description of arguments to file
class Print: Actor, Flowable {
    lazy var safeFlowable = FlowableState(self)

    lazy var beFlow = Behavior(self) { (args: BehaviorArgs) in
        // flynnlint:parameter Any
        print(args.description)
        self.safeFlowToNextTarget(args)
    }
}

// Takes a string as the first argument, passes along the uppercased version of it
class Uppercase: Actor, Flowable {
    lazy var safeFlowable = FlowableState(self)

    lazy var beFlow = Behavior(self) { (args: BehaviorArgs) in
        // flynnlint:parameter Any
        guard !args.isEmpty else { return self.safeFlowToNextTarget(args) }

        let value: String = args[x: 0]
        self.safeFlowToNextTarget([value.uppercased()])
    }
}

// Takes a string as the first argument, concatenates all strings
// received.  When it receives an empty argument list it considers
// that to be "done", and sends the concatenated string to the target
class Concatenate: Actor, Flowable {
    lazy var safeFlowable = FlowableState(self)
    private var combined: String = ""

    override init() {
        super.init()
        safePriority = 1
    }

    lazy var beFlow = Behavior(self) { (args: BehaviorArgs) in
        // flynnlint:parameter Any
        guard !args.isEmpty else { return self.safeFlowToNextTarget([self.combined]) }

        let value: String = args[x: 0]
        self.combined.append(value)
    }
}

class Callback: Actor, Flowable {
    lazy var safeFlowable = FlowableState(self)
    private let callback: ((BehaviorArgs) -> Void)!

    init(_ callback:@escaping ((BehaviorArgs) -> Void)) {
        self.callback = callback
        super.init()
    }

    lazy var beFlow = Behavior(self) { (args: BehaviorArgs) in
        // flynnlint:parameter Any
        self.callback(args)
        self.safeFlowToNextTarget(args)
    }
}
