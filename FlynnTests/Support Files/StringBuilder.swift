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
    lazy var append = Behavior(self) { (args:BehaviorArgs) in
        let a:String = args.get(0)
        self.string.append(a)
    }
    lazy var space = Behavior(self) { (args:BehaviorArgs) in
        self.string.append(" ")
    }
    lazy var result = Behavior(self) { (args:BehaviorArgs) in
        let callback:((String) -> Void) = args.get(0)
        callback(self.string)
    }
}
