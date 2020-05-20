//
//  FlynnTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import XCTest
@testable import Flynn

protocol Viewable : Actor {
    var render:Behavior<Self> { get }
}

extension Viewable {
    func _viewable_render(_ bounds:CGRect) {
        print("Viewable bounds \(bounds)")
    }
}


