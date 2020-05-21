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
    var string:String = ""
    lazy var append = ChainableBehavior(self) { (args:BehaviorArgs) in
        let a:String = args[x:0]
        self.string.append(a)
    }
    lazy var space = ChainableBehavior(self) { (args:BehaviorArgs) in
        self.string.append(" ")
    }
    lazy var result = ChainableBehavior(self) { (args:BehaviorArgs) in
        let callback:((String) -> Void) = args[x:0]
        callback(self.string)
    }
}
