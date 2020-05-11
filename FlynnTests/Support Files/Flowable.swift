//
//  FlynnTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import XCTest

@testable import Flynn


class Passthrough: Actor {
    override func chainProcess(args:BehaviorArgs) -> BehaviorArgs {
        return args
    }
}

class Print: Actor {
    override func chainProcess(args:BehaviorArgs) -> BehaviorArgs {
        print(args.description)
        return args
    }
}
