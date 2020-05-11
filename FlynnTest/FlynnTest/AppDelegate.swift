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
    
    lazy var result = Behavior<Foo>(self) { (args:BehaviorArgs) in
        let callback:((Int) -> Void) = args[0]
        callback(self.counter)
    }
}


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {



    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        
        let foo = Foo()
                
        foo.increment(1)
        foo.increment(10)
        foo.increment(20)
        foo.decrement(1)
        
        // Note: supposedly in swift 5.1 it fixes the error I see when I
        // put the closure directly in .result().  For now this works
        // around the issue
        let c = { (x:Int) in
            print("The result is \(x)")
        }
        foo.result(c)
        
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

