//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

open class Actor {

    private class func startup() {
        Flynn.startup()
    }

    private class func shutdown() {
        Flynn.shutdown()
    }

    private let uuid: String
    
    internal var ponyActor: Pony.PonyActor
    
    public var unsafeCoreAffinity: CoreAffinity {
        get {
            return ponyActor.coreAffinity
        }
        set {
            ponyActor.coreAffinity = newValue
        }
    }
    
    public var unsafePriority: Int32 {
        get {
            return ponyActor.priority
        }
        set {
            ponyActor.priority = newValue
        }
    }
    
    public var unsafeMessageBatchSize: Int32 {
        get {
            return ponyActor.batchSize
        }
        set {
            ponyActor.batchSize = newValue
        }
    }

    // MARK: - Functions
    public func unsafeWait(_ minMsgs: Int32 = 0) {
        ponyActor.wait(minMsgs)
    }

    public func unsafeYield() {
        ponyActor.yield()
    }

    public var unsafeMessagesCount: Int32 {
        return ponyActor.messageCount
    }

    private let initTime: TimeInterval = ProcessInfo.processInfo.systemUptime
    public var unsafeUptime: TimeInterval {
        return ProcessInfo.processInfo.systemUptime - initTime
    }
    
    public init() {
        Flynn.startup()
        uuid = UUID().uuidString
        ponyActor = Pony.PonyActor()
        Flynn.register(self)
    }

    deinit {
        //print("deinit - Actor")
    }

    internal func unsafeSend(_ block: @escaping BehaviorBlock, _ args: BehaviorArgs) {
        ponyActor.send(block, args)
    }
    
    internal func unsafeSend(_ block: @escaping NewBehaviorBlock) {
        ponyActor.send(block)
    }

}
