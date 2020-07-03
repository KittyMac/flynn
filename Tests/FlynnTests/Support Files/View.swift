//
//  FlynnTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import XCTest
@testable import Flynn

protocol Viewable: Actor {
    var beRender: Behavior { get }
}

extension Viewable {
    func safeViewableRender(_ bounds: CGRect) {
        print("Viewable bounds \(bounds)")
    }
}
