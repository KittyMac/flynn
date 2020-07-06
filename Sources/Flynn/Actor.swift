//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

class ActorMessage {
    var actor: Actor?
    var block: BehaviorBlock?
    var args: BehaviorArgs?
    init(_ actorIn: Actor, _ blockIn: @escaping BehaviorBlock, _ argsIn: BehaviorArgs) {
        actor = actorIn
        block = blockIn
        args = argsIn
    }

    func set(_ actorIn: Actor, _ blockIn: @escaping BehaviorBlock, _ argsIn: BehaviorArgs) {
        actor = actorIn
        block = blockIn
        args = argsIn
    }

    func run() {
        block!(args!)
    }

    func clear() {
        actor = nil
        block = nil
        args = nil
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

    public var safePriority: Int32 {
        set { withExtendedLifetime(newValue) { } }
        get { return 0 }
    }

    public var safeCoreAffinity: CoreAffinity = .preferEfficiency

    // MARK: - Functions
    public func unsafeWait(_ minMsgs: Int32 = 0) {
        var scalingSleep: UInt32 = 10
        let maxScalingSleep: UInt32 = 500

        var timeSlept: UInt32 = 0
        while messages.count > minMsgs {
            usleep(scalingSleep)

            timeSlept += scalingSleep

            scalingSleep += 1
            if scalingSleep > maxScalingSleep {
                scalingSleep = maxScalingSleep
            }
        }

        //print("timeSlept: \(timeSlept)")
    }

    private var yield: Bool = false
    public func unsafeYield() {
        yield = true
    }

    public func unsafeShouldWaitOnActors(_ actors: [Actor]) -> Bool {
        var num: Int32 = 0
        for actor in actors {
            num += actor.unsafeMessagesCount
        }
        return num > 0
    }

    public var unsafeMessagesCount: Int32 {
        //return messagesCount.value
        return Int32(messages.count)
    }

    private var hasUnbalancedRetain: Bool = true
    public init() {
        Flynn.startup()
        uuid = UUID().uuidString

        // This is required because with programming patterns like
        // Actor().beBehavior() Swift will dealloc the actor prior
        // to the behavior being called. So we introduce an unbalanced
        // retain which we release as soon as this actor processes its
        // first message.
        _ = Unmanaged.passRetained(self)
    }

    deinit {
        print("deinit - Actor")
    }

    private var messagePool = Queue<ActorMessage>(128)
    private func unpoolActorMessage(_ block: @escaping BehaviorBlock, _ args: BehaviorArgs) -> ActorMessage {
        if let msg = messagePool.dequeue() {
            msg.set(self, block, args)
            return msg
        }
        return ActorMessage(self, block, args)
    }

    private func poolActorMessage(_ msg: ActorMessage) {
        msg.clear()
        messagePool.enqueue(msg)
    }

    private var messages = Queue<ActorMessage>(128)
    internal func unsafeSend(_ block: @escaping BehaviorBlock, _ args: BehaviorArgs) {
        if messages.enqueue(unpoolActorMessage(block, args)) {
            Flynn.schedule(self, safeCoreAffinity)
        }
    }

    private var runningLock = NSLock()
    internal func unsafeRun() {
        if runningLock.try() {
            //print("run \(self)")
            var maxMessages = 1000
            while let msg = messages.peek() {

                //print("  msg for \(self)")
                msg.run()
                poolActorMessage(messages.dequeue()!)

                maxMessages -= 1
                if maxMessages <= 0 {
                    break
                }

                if yield {
                    yield = false
                    break
                }
            }

            if hasUnbalancedRetain {
                _ = Unmanaged.passUnretained(self).release()
                hasUnbalancedRetain = false
            }

            runningLock.unlock()
        }

        if !messages.markEmpty() {
            Flynn.schedule(self, safeCoreAffinity)
        }
    }
}
