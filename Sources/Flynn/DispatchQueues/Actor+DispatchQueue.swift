//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

#if !PLATFORM_SUPPORTS_PONYRT

internal extension Actor {
    @discardableResult
    func unsafeRetain() -> Self {
        _ = Unmanaged.passRetained(self)
        return self
    }
    @discardableResult
    func unsafeRelease() -> Self {
        _ = Unmanaged.passUnretained(self).release()
        return self
    }
}

open class Actor {

    public enum CoreAffinity: Int32 {
        case preferEfficiency = 0
        case preferPerformance = 1
        case onlyEfficiency = 2
        case onlyPerformance = 3
    }

    private class func startup() {
        Flynn.startup()
    }

    private class func shutdown() {
        Flynn.shutdown()
    }

    private let uuid: String

    private lazy var dispatchQueue = DispatchQueue(label: "actor.\(uuid).queue", qos: dispatchQoS)
    private var dispatchQoS: DispatchQoS = .userInitiated

    public var safePriority: Int32 {
        set { withExtendedLifetime(newValue) { } }
        get { return 0 }
    }

    public var safeCoreAffinity: CoreAffinity {
        set {
            switch newValue {
            case .onlyEfficiency, .preferEfficiency:
                dispatchQoS = .utility
            case .onlyPerformance, .preferPerformance:
                dispatchQoS = .userInitiated
            }
        }
        get { return CoreAffinity.preferEfficiency }
    }

    // MARK: - Functions
    public func unsafeWait(_ minMsgs: Int32 = 0) {
        // with dispatch queues we can only wait unti end
        if minMsgs > 0 {
            print("warning: Flynn (using dispatch queues) does not support waiting for message counts other than 0")
        }
        dispatchQueue.sync { }
    }

    public func unsafeYield() {
        // yielding is not supported with DispatchQueues
    }

    public func unsafeShouldWaitOnActors(_ actors: [Actor]) -> Bool {
        var num: Int32 = 0
        for actor in actors {
            num += actor.unsafeMessagesCount
        }
        return num > 0
    }

    public var unsafeMessagesCount: Int32 {
        return Int32(messages.count)
    }

    public init() {
        Flynn.startup()
        uuid = UUID().uuidString

        // This is required because with programming patterns like
        // Actor().beBehavior() Swift will dealloc the actor prior
        // to the behavior being called.
        self.unsafeRetain()
        dispatchQueue.asyncAfter(deadline: .now() + 1.0) {
            self.unsafeRelease()
        }
    }

    deinit {
        print("deinit - Actor")
    }

    private var messages = Queue<(BehaviorBlock, BehaviorArgs)>()
    private var running: Bool = false
    private lazy var runBlock = DispatchWorkItem { self.run() }
    internal func unsafeSend(_ block: @escaping BehaviorBlock, _ args: BehaviorArgs) {
        messages.enqueue((block, args))
        if !running {
            running = true
            dispatchQueue.async(execute: runBlock)
        }
    }

    private func run() {
        while let msg = messages.dequeue() {
            msg.0(msg.1)
        }
        running = false
    }
}

private struct Queue<T> {
    // safe only so long as there is one consumer and multiple producers
    fileprivate var array = [T?](repeating: nil, count: 2)
    fileprivate var writeIdx = 0
    fileprivate var readIdx = 0
    fileprivate var readLock = NSLock()
    fileprivate var growLock = NSLock()

    public var isEmpty: Bool {
        return writeIdx == readIdx
    }

    public var isFull: Bool {
        return nextIndex(writeIdx) == readIdx
    }

    public var count: Int {
        let localReadIdx = readIdx
        let localWriteIdx = writeIdx
        if localWriteIdx == localReadIdx {
            return 0
        }
        if localWriteIdx > localReadIdx {
            return localWriteIdx - localReadIdx
        }
        return array.count - (localReadIdx - localWriteIdx)
    }

    public mutating func grow() {
        growLock.lock()
        var newArray = [T?](repeating: nil, count: array.count * 2)

        var oldReadIdx = readIdx
        var newWriteIdx = 0
        while oldReadIdx != writeIdx {
            newArray[newWriteIdx] = array[oldReadIdx]
            oldReadIdx = nextIndex(oldReadIdx)
            newWriteIdx += 1
        }

        array = newArray
        writeIdx = newWriteIdx
        readIdx = 0

        //print("grow[\(array.count)]  \(readIdx) // \(writeIdx)")

        growLock.unlock()
    }

    private func nextIndex(_ idx: Int) -> Int {
        var num = idx + 1
        if num >= array.count {
            num = 0
        }
        return num
    }

    public mutating func enqueue(_ element: T) {
        readLock.lock()
        while isFull {
            grow()
        }
        //print("enqueue[\(writeIdx)]  \(element)")
        array[writeIdx] = element
        writeIdx = nextIndex(writeIdx)
        readLock.unlock()
    }

    public mutating func dequeue() -> T? {
        if isEmpty {
            return nil
        }
        growLock.lock()
        let element = array[readIdx]
        array[readIdx] = nil
        //print("dequeue[\(readIdx)]  \(element)")
        growLock.unlock()

        readIdx = nextIndex(readIdx)
        return element
    }
}

#endif
