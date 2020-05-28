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
        counter = counter + 1
    }
}

class OffToTheRacesActor : Actor {
    
    let _data:OffToTheRacesData
    
    init(_ data:OffToTheRacesData) {
        _data = data
    }
        
    lazy var inc = ChainableBehavior(self) { (args:BehaviorArgs) in
        self._data.inc()
    }
}

class WhoseCallWasThisAnyway : Actor {
    
    lazy var printFoo = ChainableBehavior(self) { (args:BehaviorArgs) in
        print("foo")
    }
    
    func printBar() {
        print("bar")
    }
    
}


class BadFlynnTests: XCTestCase {

    override func setUp() {
        Actor.startup()
    }

    override func tearDown() {
        Actor.shutdown()
    }

    func testDataRace() {
        // https://github.com/KittyMac/flynn/issues/9
        let sharedData = OffToTheRacesData()
        let actor0 = OffToTheRacesActor(sharedData)
        let actor1 = OffToTheRacesActor(sharedData)
        let actor2 = OffToTheRacesActor(sharedData)
        let actor3 = OffToTheRacesActor(sharedData)
        let actor4 = OffToTheRacesActor(sharedData)
        let n = 100000
        
        for _ in 0..<n {
            actor0.inc()
            actor1.inc()
            actor2.inc()
            actor3.inc()
            actor4.inc()
        }
        
        actor0.wait(0)
        actor1.wait(0)
        actor2.wait(0)
        actor3.wait(0)
        actor4.wait(0)
        
        print("got \(sharedData.counter) when I expected to get \(n*5)")
        
        XCTAssert(sharedData.counter == (n*5))
    }
    
    func testCallSiteUncertainty() {
        // https://github.com/KittyMac/flynn/issues/8
        
        let a = WhoseCallWasThisAnyway()
        
        // Since calls to functions and calls to behaviors are visually similar,
        // and we cannot enforce developers NOT to have non-private functions,
        // someone reading this would think it would print a bunch of "foo"
        // followed by a bunch of "bar".  Oh, they'd be so wrong.
        a.printFoo()
        a.printFoo()
        a.printFoo()
        a.printFoo()
        a.printFoo()
        a.printFoo()
        a.printFoo()
        a.printBar()
        a.printBar()
        a.printBar()
        a.printBar()
        a.printBar()
        a.printBar()
        a.printBar()
        a.printBar()
        
    }
        
}
