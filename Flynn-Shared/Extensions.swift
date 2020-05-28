//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

public typealias NewObject = (() -> AnyObject)

extension Array {
    public init(count: Int, create: NewObject) {
        self.init()
        for _ in 0..<count {
            self.append(create() as! Element) // swiftlint:disable:this force_cast
        }
    }
}
