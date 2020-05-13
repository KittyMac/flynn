//
//  PonyRTTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import XCTest
import Flynn

class PonyRTTests: XCTestCase {

    override func setUp() {
        Actor.startup()
    }

    override func tearDown() {
        Actor.shutdown()
    }

    func testScheduleActor1() {
        
        let actor = pony_actor_create()
        
        pony_actor_dispatch(actor, nil);
        pony_actor_dispatch(actor, nil);
        pony_actor_dispatch(actor, nil);
        pony_actor_dispatch(actor, nil);
        pony_actor_dispatch(actor, nil);
        
        Thread.sleep(forTimeInterval: 1)
        
        pony_actor_destroy(actor)
    }


}
