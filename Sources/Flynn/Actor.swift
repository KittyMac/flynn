//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

class ActorMessage {
    private static var emptyArgs: BehaviorArgs = []
    
    private unowned var actor: Actor?
    private var block: BehaviorBlock?
    
    private var numArgs: Int = 0
    private var args: BehaviorArgs?
    private var arg: Any?
    
    init(_ actorIn: Actor, _ blockIn: @escaping BehaviorBlock, _ argsIn: BehaviorArgs) {
        actor = actorIn
        block = blockIn
        
        numArgs = argsIn.count
        switch(numArgs) {
        case 0:
            break
        case 1:
            arg = argsIn[0]
        default:
            args = argsIn
        }
    }

    @inline(__always)
    func set(_ actorIn: Actor, _ blockIn: @escaping BehaviorBlock, _ argsIn: BehaviorArgs) {
        actor = actorIn
        block = blockIn
        
        numArgs = argsIn.count
        switch(numArgs) {
        case 0:
            break
        case 1:
            arg = argsIn[0]
        default:
            args = argsIn
        }
    }

    @inline(__always)
    func run() {
        switch(numArgs) {
        case 0:
            block!(ActorMessage.emptyArgs)
        case 1:
            block!([arg]);
            arg = nil
        default:
            block!(args!);
            args = nil
        }
        actor = nil
        block = nil
    }

    deinit {
        //print("deinit - ActorMessage")
    }
}

open class Actor {

    private class func startup() {
        Flynn.startup()
    }

    private class func shutdown() {
        Flynn.shutdown()
    }

    private let uuid: String

    public var unsafeMessageBatchSize: UInt = 1000
    public var unsafePriority: Int = 0
    public var unsafeCoreAffinity: CoreAffinity = Flynn.defaultActorAffinity
    
    internal let ponyActor: Pony.PonyActor

    // MARK: - Functions
    public func unsafeWait(_ minMsgs: Int32 = 0) {
        var scalingSleep: UInt32 = 10
        let maxScalingSleep: UInt32 = 500

        var timeSlept: UInt32 = 0
        while ponyActor.messageCount > minMsgs {
            usleep(scalingSleep)

            timeSlept += scalingSleep

            scalingSleep += 1
            if scalingSleep > maxScalingSleep {
                scalingSleep = maxScalingSleep
            }
        }
    }

    private var yield: Bool = false
    public func unsafeYield() {
        yield = true
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
        ponyActor.attach(self)
    }

    deinit {
        //print("deinit - Actor")
    }

    internal func unsafeSend(_ block: @escaping BehaviorBlock, _ args: BehaviorArgs) {
        ponyActor.send(block, args)
    }

}
