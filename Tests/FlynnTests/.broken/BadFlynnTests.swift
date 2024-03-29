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

    internal func _beCount() {
        self.data.inc()
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
            actor0.beCount()
            actor1.beCount()
            actor2.beCount()
            actor3.beCount()
            actor4.beCount()
        }

        actor0.unsafeWait(0)
        actor1.unsafeWait(0)
        actor2.unsafeWait(0)
        actor3.unsafeWait(0)
        actor4.unsafeWait(0)

        print("got \(sharedData.counter) when I expected to get \(num * 5)")

        XCTAssert(sharedData.counter == (num * 5))
    }
}
