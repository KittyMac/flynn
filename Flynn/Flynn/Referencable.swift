//
//  Referencable.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// The challenge: how to ensure that only one alias to an an object ever exists?  You adhere
// to referencable, we store which thread has control of it, and we don't allow any
// other thread to ever access it

import Foundation

class Referencable {
    var owner:Thread?
    
    init () {
        owner = Thread.current
    }
    
    func consume () {
        if owner == Thread.current {
            owner = nil
        } else {
            exit(99)
        }
    }
    
}


