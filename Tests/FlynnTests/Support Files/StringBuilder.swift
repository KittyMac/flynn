//
//  FlynnTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import XCTest

@testable import Flynn

class StringBuilder: Actor {
    private var string: String = ""
    lazy var append = ChainableBehavior(self) { (args: BehaviorArgs) in
        let value: String = args[x: 0]
        self.string.append(value)
    }
    lazy var space = ChainableBehavior(self) { (_: BehaviorArgs) in
        self.string.append(" ")
    }
    lazy var result = ChainableBehavior(self) { (args: BehaviorArgs) in
        let callback: ((String) -> Void) = args[x:0]
        callback(self.string)
    }
}
