//
//  FlynnTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// Unit tests which expose problems in Flynn still need to address

import XCTest

@testable import Flynn

class OffToTheRacesData {
    var counter = 0

    func inc() {
        counter +=  1
    }
}

class OffToTheRacesActor: Actor {
    private let data: OffToTheRacesData

    init(_ data: OffToTheRacesData) {
        self.data = data
    }

    lazy var beInc = ChainableBehavior(self) { (_: BehaviorArgs) in
        // flynnlint:parameter None
        self.data.inc()
    }
}

class PublicVariablesAreAlsoBad: Actor {

    private var shouldBeError: Int = 0

    lazy var beShouldNotBeError = ChainableBehavior(self) { (_: BehaviorArgs) in
        // flynnlint:parameter None
        print("bar")
    }
}

class WhoseCallWasThisAnyway: Actor {
    lazy var bePrintFoo = ChainableBehavior(self) { (_: BehaviorArgs) in
        // flynnlint:parameter None
        print("foo")
    }
}

class BadFlynnTests: XCTestCase {

    override func setUp() {
        Flynn.startup()
    }

    override func tearDown() {
        Flynn.shutdown()
    }

    func testDataRace() {
        // https://github.com/KittyMac/flynn/issues/9
        let sharedData = OffToTheRacesData()
        let actor0 = OffToTheRacesActor(sharedData)
        let actor1 = OffToTheRacesActor(sharedData)
        let actor2 = OffToTheRacesActor(sharedData)
        let actor3 = OffToTheRacesActor(sharedData)
        let actor4 = OffToTheRacesActor(sharedData)
        let num = 100000

        for _ in 0..<num {
            actor0.beInc()
            actor1.beInc()
            actor2.beInc()
            actor3.beInc()
            actor4.beInc()
        }

        actor0.unsafeWait(0)
        actor1.unsafeWait(0)
        actor2.unsafeWait(0)
        actor3.unsafeWait(0)
        actor4.unsafeWait(0)

        print("got \(sharedData.counter) when I expected to get \(num * 5)")

        XCTAssert(sharedData.counter == (num * 5))
    }

    func testCallSiteUncertainty() {
        // https://github.com/KittyMac/flynn/issues/8

        let actor = WhoseCallWasThisAnyway()

        // Since calls to functions and calls to behaviors are visually similar,
        // and we cannot enforce developers NOT to have non-private functions,
        // someone reading this would think it would print a bunch of "foo"
        // followed by a bunch of "bar".  Oh, they'd be so wrong.
        actor.bePrintFoo()
        actor.bePrintFoo()
        actor.bePrintFoo()
        actor.bePrintFoo()
        actor.bePrintFoo()
        actor.bePrintFoo()
        actor.bePrintFoo()

        actor.unsafeWait(0)
    }
}
