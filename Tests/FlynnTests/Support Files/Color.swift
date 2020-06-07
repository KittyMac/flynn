//
//  FlynnTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import XCTest
@testable import Flynn
import GLKit

// swiftlint:disable identifier_name

public class ColorableState {
    var _color: GLKVector4 = GLKVector4Make(1, 1, 1, 1)

    var color: Behavior?
    var alpha: Behavior?

    init (_ actor: Actor) {
        color = Behavior(actor) { (args: BehaviorArgs) in
            self._color = args[x:0]
        }
        alpha = Behavior(actor) { (args: BehaviorArgs) in
            self._color.a = args[x:0]
        }
    }
}

public protocol Colorable: Actor {
    var unsafeColorable: ColorableState { get set }
}

public extension Colorable {

    func red() -> Self {
        unsafeColorable.color!(GLKVector4Make(1, 0, 0, 1))
        return self
    }

}

public final class Color: Actor, Viewable, Colorable {
    public lazy var unsafeColorable = ColorableState(self)

    public lazy var beRender = Behavior(self) { (_: BehaviorArgs) in
        // flynnlint:parameter None
        print("render!")
    }

    public func unsafeFoo() {
        print("this is an unsafe function")
    }
}
