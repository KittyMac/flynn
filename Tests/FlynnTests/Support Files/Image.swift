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

public class ImageableState {
    private var path: String = ""

    lazy var bePath = Behavior { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter String - The path to the image
        print("Imageable.path from \(self)")
        self.path = args[x:0]
    }

    init (_ actor: Actor) {
        bePath.setActor(actor)
    }
}

protocol Imageable: Actor {
    var safeImageable: ImageableState { get set }
    var bePath: Behavior { get }
}

extension Imageable {
    var bePath: Behavior { return safeImageable.bePath }
}

public final class Image: Actor, Colorable, Imageable, Viewable {
    public lazy var safeColorable = ColorableState(self)
    public lazy var safeImageable = ImageableState(self)

    public lazy var beRender = Behavior(self) { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter CGRect - The bounds in which to render the view
        self.safeViewableRender(args[x:0])
    }
}
