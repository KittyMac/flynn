//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

func bridge<T: AnyObject>(obj: T) -> UnsafeRawPointer {
    return UnsafeRawPointer(Unmanaged.passRetained(obj).toOpaque())
}

func bridge<T: AnyObject>(ptr: UnsafeRawPointer) -> T {
    return Unmanaged<T>.fromOpaque(ptr).takeRetainedValue()
}

func bridgePeek<T: AnyObject>(ptr: UnsafeRawPointer) -> T {
    return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
}

public class Queue<T: AnyObject> {
    // safe only so long as there is one consumer and multiple producers
    private let arrayResizing: Bool
    private var arraySize: Int = 0
    private var arrayPtr: UnsafeMutablePointer<UnsafeRawPointer?>

    private var writeIdx = 0
    private var readIdx = 0

    private var readLock: NSLock?
    private var writeLock: NSLock?
    
    private let multipleProducers: Bool
    private let multipleConsumers: Bool

    public init(_ size: Int,
                _ resizing: Bool = true,
                _ multipleProducers: Bool = true,
                _ multipleConsumers: Bool = true) {

        arrayResizing = resizing
        arraySize = size
        arrayPtr = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: arraySize)
        arrayPtr.initialize(repeating: nil, count: arraySize)
        
        self.multipleProducers = multipleProducers
        self.multipleConsumers = multipleConsumers

        // Note: if the queue cannot grow, and we have only one producer or one consumer
        // then we can get away with not having those specific locks
        if multipleConsumers || resizing {
            readLock = NSLock()
        }
        if multipleProducers || resizing {
            writeLock = NSLock()
        }
    }

    deinit {
        clear()
        arrayPtr.deallocate()
        //print("deinit - Queue")
    }

    @inline(__always)
    public var isEmpty: Bool {
        return writeIdx == readIdx
    }

    @inline(__always)
    public var isFull: Bool {
        return ((writeIdx + 1) % arraySize) == readIdx
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
        return arraySize - (localReadIdx - localWriteIdx)
    }

    private func grow() {
        readLock?.lock()

        let oldArraySize = arraySize
        arraySize *= 2
        let newArrayPtr = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: arraySize)
        newArrayPtr.initialize(repeating: nil, count: arraySize)

        var oldReadIdx = readIdx
        var newWriteIdx = 0
        while oldReadIdx != writeIdx {
            (newArrayPtr+newWriteIdx).pointee = (arrayPtr+oldReadIdx).pointee
            oldReadIdx = (oldReadIdx + 1) % oldArraySize
            newWriteIdx += 1
        }

        arrayPtr.deallocate()
        arrayPtr = newArrayPtr
        writeIdx = newWriteIdx
        readIdx = 0

        readLock?.unlock()
        //print("grow[\(arraySize)]  \(readIdx) // \(writeIdx)")
    }

    @discardableResult
    public func enqueue(_ element: T) -> Bool {
        writeLock?.lock()

        let wasEmpty = (writeIdx == readIdx)
        while isFull {
            if arrayResizing == false {
                writeLock?.unlock()
                return false
            }
            grow()
        }

        //print("enqueue[\(writeIdx)]  \(elementPtr)")

        (arrayPtr+writeIdx).pointee = bridge(obj: element)
        writeIdx = (writeIdx + 1) % arraySize

        writeLock?.unlock()

        return wasEmpty
    }
    
    @discardableResult
    public func enqueue(_ element: T, sortedBy closure: (T, T) -> Bool) -> Bool {
        if readLock == nil {
            print("Sorted enqueuing is only supported on queues which allow resizing")
            fatalError()
        }
        
        writeLock?.lock()

        let wasEmpty = (writeIdx == readIdx)
        while isFull {
            if arrayResizing == false {
                writeLock?.unlock()
                return false
            }
            grow()
        }

        // for sorted enqueuing, we need to capture the read lock and then
        // insert our new item in the correct spot.
        readLock?.lock()
        
        var idx = readIdx
        while idx != writeIdx {
            if let elementPtr = (arrayPtr+idx).pointee {
                let lhs: T = bridgePeek(ptr: elementPtr)
                if closure(lhs, element) {
                    
                    // We need to insert the new one here. Do that, then move everything down.
                    var bubble: UnsafeRawPointer? = bridge(obj: element)
                    while idx != writeIdx {
                        let temp = (arrayPtr+idx).pointee
                        (arrayPtr+idx).pointee = bubble
                        bubble = temp
                        idx = (idx + 1) % arraySize
                    }
                    (arrayPtr+writeIdx).pointee = bubble
                    writeIdx = (writeIdx + 1) % arraySize
                    
                    readLock?.unlock()
                    writeLock?.unlock()
                    return wasEmpty
                }
            }
            idx = (idx + 1) % arraySize
        }

        (arrayPtr+writeIdx).pointee = bridge(obj: element)
        writeIdx = (writeIdx + 1) % arraySize
        
        readLock?.unlock()
        writeLock?.unlock()

        return wasEmpty
    }

    @discardableResult
    public func dequeue() -> T? {
        readLock?.lock()

        let elementPtr = (arrayPtr+readIdx).pointee
        if elementPtr == nil {
            readLock?.unlock()
            return nil
        }
        //print("dequeue[\(readIdx)]  \(elementPtr!)")

        (arrayPtr+readIdx).pointee = nil
        readIdx = (readIdx + 1) % arraySize

        readLock?.unlock()
        return bridge(ptr: elementPtr!)
    }
    
    public func dequeueIf(_ closure: (T) -> Bool) -> T? {
        if writeIdx == readIdx {
            return nil
        }

        readLock?.lock()
        let elementPtr = (arrayPtr+readIdx).pointee
        if elementPtr == nil {
            readLock?.unlock()
            return nil
        }
        
        let item: T = bridgePeek(ptr: elementPtr!)
        if closure(item) {
            (arrayPtr+readIdx).pointee = nil
            readIdx = (readIdx + 1) % arraySize
            let element: T = bridge(ptr: elementPtr!)
            readLock?.unlock()
            return element
        }
        
        readLock?.unlock()
        return nil
    }

    public func peek() -> T? {
        if multipleConsumers {
            print("Queues which allow multiple consumers cannot use peek() safely")
            fatalError()
        }
        if writeIdx == readIdx {
            return nil
        }

        readLock?.lock()
        let elementPtr = (arrayPtr+readIdx).pointee
        if elementPtr == nil {
            readLock?.unlock()
            return nil
        }
        readLock?.unlock()
        return bridgePeek(ptr: elementPtr!)
    }

    public func clear() {
        readLock?.lock()

        while let elementPtr = (arrayPtr+readIdx).pointee {
            let _: T = bridge(ptr: elementPtr)
            (arrayPtr+readIdx).pointee = nil
            readIdx = (readIdx + 1) % arraySize
        }

        readLock?.unlock()
    }

    public func markEmpty() -> Bool {
        writeLock?.lock()
        readLock?.lock()
        let wasEmpty = (writeIdx == readIdx)
        readLock?.unlock()
        writeLock?.unlock()
        return wasEmpty
    }
}
