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

public class ColorableState<T: Actor> {
    private var color: GLKVector4 = GLKVector4Make(1, 1, 1, 1)

    lazy var beColor = ChainableBehavior<T> { (_: BehaviorArgs) in
        print("Colorable.color from \(self)")
    }

    lazy var beAlpha = ChainableBehavior<T> { (_: BehaviorArgs) in
        print("Colorable.alpha from \(self)")
    }

    lazy var beGetColor = Behavior { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter Behavior - The behavior to supply the results to
        let callback: Behavior = args[x:0]
        callback(self.color)
    }

    lazy var beSetColor = Behavior { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter GLKVector4 - the color array
        self.color = args[x:0]
    }

    init (_ actor: T) {
        beColor.setActor(actor)
        beAlpha.setActor(actor)
        beGetColor.setActor(actor)
        beSetColor.setActor(actor)
    }
}

protocol Colorable: Actor {
    var safeColorable: ColorableState<Self> { get set }
}

extension Colorable {
    var beColor: ChainableBehavior<Self> { return safeColorable.beColor }
    var beAlpha: ChainableBehavior<Self> { return safeColorable.beAlpha }
    var beGetColor: Behavior { return safeColorable.beGetColor }
    var beSetColor: Behavior { return safeColorable.beSetColor }
}

public final class Color: Actor, Colorable, Viewable {
    public lazy var safeColorable = ColorableState(self)

    public lazy var beRender = Behavior(self) { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter CGRect - The bounds in which to render the view
        self.safeViewableRender(args[x:0])
    }
}
