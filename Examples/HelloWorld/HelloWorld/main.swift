//
//  main.swift
//  HelloWorld
//
//  Created by Rocco Bowling on 6/26/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import Flynn

class HelloWorld: Actor {
    lazy var bePrint = Behavior(self) { (args: BehaviorArgs) in
        // flynnlint:parameter String - string to print
        print(args[x:0])
    }
}

HelloWorld().bePrint("hello!")

Flynn.shutdown()
