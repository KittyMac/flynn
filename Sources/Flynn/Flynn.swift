//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import Pony

open class Flynn {
    internal static var ponyIsStarted: Bool = false

    public class func startup() {
        pony_startup()
        ponyIsStarted = true
    }

    public class func shutdown() {
        pony_shutdown()
        ponyIsStarted = false
    }

    public static var cores: Int {
        return Int(pony_core_count())
    }

    public static var cpus: Int {
        return Int(pony_cpu_count())
    }

}
