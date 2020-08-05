//
//  FlynnTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import XCTest

@testable import Flynn

class PassToMe: Actor {

    public func unsafePrint(_ string: String) {
        print(string)
    }

    lazy var beNone = Behavior(self) { (_: BehaviorArgs) in
        print("hello world with no arguments")
    }
    
    lazy var beString = ChainableBehavior(self) { (args: BehaviorArgs) in
        // flynnlint:parameter String - a swift string ( a struct )
        print("hello world from " + args[x:0])
    }

    lazy var beNSString = ChainableBehavior(self) { (args: BehaviorArgs) in
        // flynnlint:parameter NSString - a object string
        print("hello world from " + args[x:0])
    }
}
