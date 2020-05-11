//
//  AppDelegate.swift
//  FlynnTest
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Cocoa
import Flynn


class Foo: Actor {
    
    var counter:Int = 0
    
    lazy var increment = Behavior<Foo>(self) { (args:BehaviorArgs) in
        let n:Int = args[0]
        self.counter += n
    }
    
    lazy var decrement = Behavior<Foo>(self) { (args:BehaviorArgs) in
        let n:Int = args[0]
        self.counter -= n
    }
    
    lazy var result = UIBehavior<Foo>(self) { (args:BehaviorArgs) in
        let callback:((Int) -> Void) = args[0]
        callback(self.counter)
    }
}


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {



    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        
        let foo = Foo()
        
        print("before")
        foo.increment(1)
           .increment(10)
           .increment(20)
           .decrement(1)
           .result({ (x:Int) in
               print("The result is \(x)")
           })
        print("after")
        
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

