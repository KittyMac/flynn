//
//  FlynnTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import XCTest
@testable import Flynn

final class Color: Actor, Viewable {
    lazy var render = Behavior(self) { (args:BehaviorArgs) in
        let bounds:CGRect = args[x:0]
        self._viewable_render(bounds)
        print("Color bounds \(bounds)")
    }
}


