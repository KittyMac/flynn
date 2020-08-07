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
    var safeFlowable = FlowableState()

    private func _beFlow(_ args: FlowableArgs) {
        safeFlowToNextTarget(args)
    }
    func beFlow(_ args: FlowableArgs) {
        unsafeSend { [unowned self] in
            self._beFlow(args)
        }
    }
}

// Print description of arguments to file
class Print: Actor, Flowable {
    var safeFlowable = FlowableState()
    
    private func _beFlow(_ args: FlowableArgs) {
        print(args.description)
        safeFlowToNextTarget(args)
    }
    func beFlow(_ args: FlowableArgs) {
        unsafeSend { [unowned self] in
            self._beFlow(args)
        }
    }
}

// Takes a string as the first argument, passes along the uppercased version of it
class Uppercase: Actor, Flowable {
    var safeFlowable = FlowableState()
    
    private func _beFlow(_ args: FlowableArgs) {
        guard !args.isEmpty else { return self.safeFlowToNextTarget(args) }
        let value: String = args[x: 0]
        safeFlowToNextTarget([value.uppercased()])
    }
    func beFlow(_ args: FlowableArgs) {
        unsafeSend { [unowned self] in
            self._beFlow(args)
        }
    }
}

// Takes a string as the first argument, concatenates all strings
// received.  When it receives an empty argument list it considers
// that to be "done", and sends the concatenated string to the target
class Concatenate: Actor, Flowable {
    var safeFlowable = FlowableState()
    private var combined: String = ""

    override init() {
        super.init()
        unsafePriority = 1
    }

    private func _beFlow(_ args: FlowableArgs) {
        guard !args.isEmpty else { return self.safeFlowToNextTarget([self.combined]) }
        let value: String = args[x: 0]
        combined.append(value)
    }
    func beFlow(_ args: FlowableArgs) {
        unsafeSend { [unowned self] in
            self._beFlow(args)
        }
    }
}

class Callback: Actor, Flowable {
    var safeFlowable = FlowableState()
    private let callback: ((FlowableArgs) -> Void)!

    init(_ callback:@escaping ((FlowableArgs) -> Void)) {
        self.callback = callback
        super.init()
    }
    
    private func _beFlow(_ args: FlowableArgs) {
        callback(args)
        safeFlowToNextTarget(args)
    }
    func beFlow(_ args: FlowableArgs) {
        unsafeSend { [unowned self] in
            self._beFlow(args)
        }
    }
}

