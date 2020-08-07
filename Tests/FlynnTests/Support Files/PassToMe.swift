//
//  FlynnTests.swift
//  FlynnTests
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import XCTest

@testable import Flynn

class PassToMe: Actor {

    public func unsafePrint(_ string: String) {
        print(string)
    }
    
    private func _beNone() {
        print("hello world with no arguments")
    }

    private func _beString(_ string: String) {
        print(string)
    }
    
    private func _beNSString (_ string: NSString) {
        print(string)
    }
    
}

extension PassToMe {
    public func beNone() {
        unsafeSend(_beNone)
    }
    
    public func beString(_ string: String) {
        unsafeSend { [unowned self] in
            self._beString(string)
        }
    }
    
    public func beNSString(_ string: NSString) {
        unsafeSend { [unowned self] in
            self._beNSString(string)
        }
    }
}
