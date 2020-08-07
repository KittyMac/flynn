//
//  FlynnTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import XCTest

@testable import Flynn

/*

class StringBuilder: Actor {
    private var string: String = ""

    lazy var beAppend = ChainableBehavior(self) { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter String - the string to be appended
        let value: String = args[x: 0]
        self.string.append(value)
    }

    lazy var beSpace = ChainableBehavior(self) { [unowned self] (_: BehaviorArgs) in
        // flynnlint:parameter None
        self.string.append(" ")
    }

    lazy var beResult = ChainableBehavior(self) { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter String - closure to call when the string is completed
        let callback: ((String) -> Void) = args[x:0]
        callback(self.string)
    }
}

*/
