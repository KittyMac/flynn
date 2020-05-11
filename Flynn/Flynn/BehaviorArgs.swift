//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation


public typealias BehaviorArgs = KeyValuePairs<String, Any>

public extension KeyValuePairs {
    // Find the first occurrence of the key named key and return it
    subscript<T>(_ idx: Int) -> T {
        return self[idx].value as! T
    }
}
