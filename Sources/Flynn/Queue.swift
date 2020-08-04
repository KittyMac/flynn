//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

public class Queue<T: AnyObject> {
    // safe only so long as there is one consumer and multiple producers
    private let arrayResizing: Bool
    private var arraySize: Int = 0
    private var arrayPtr: UnsafeMutablePointer<T?>

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
        arrayPtr = UnsafeMutablePointer<T?>.allocate(capacity: arraySize)
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
    
    public func dump() {
        print("Queue \(self)")
        print("cout: \(count)")
        print("isEmpty: \(isEmpty)")
        
        let readElement = (arrayPtr+readIdx).pointee
        let writeElement = (arrayPtr+writeIdx).pointee
        print("readIdx: \(readIdx), value: \(String(describing: readElement))")
        print("writeIdx: \(writeIdx), value: \(String(describing: writeElement))")
        print("arraySize: \(arraySize)")
        print("\n")
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
        let newArrayPtr = UnsafeMutablePointer<T?>.allocate(capacity: arraySize)
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

        (arrayPtr+writeIdx).pointee = element
        writeIdx = (writeIdx + 1) % arraySize

        writeLock?.unlock()

        return wasEmpty
    }
    
    @discardableResult
    public func enqueue(_ element: T, sortedBy closure: (T, T) -> Bool) -> Bool {
        // Note: sorting while enqueing is slow, because the writer needs to lock both
        // the read and the write before inserting in sorted order. Generally, this
        // function should be avoided in favor of dequeue-ing out of order
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
                let lhs: T = elementPtr
                if closure(lhs, element) {
                    
                    // We need to insert the new one here. Do that, then move everything down.
                    var bubble: T? = element
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

        (arrayPtr+writeIdx).pointee = element
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
        return elementPtr!
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
        
        let item: T = elementPtr!
        if closure(item) {
            (arrayPtr+readIdx).pointee = nil
            readIdx = (readIdx + 1) % arraySize
            let element: T = elementPtr!
            readLock?.unlock()
            return element
        }
        
        readLock?.unlock()
        return nil
    }
    
    public func dequeueAny(_ closure: (T) -> Bool) {
        if writeIdx == readIdx {
            return
        }
        
        readLock?.lock()
        let elementPtr = (arrayPtr+readIdx).pointee
        if elementPtr == nil {
            readLock?.unlock()
            return
        }
        
        var tempIdx = readIdx
        let savedWriteIdx = writeIdx
        while tempIdx != savedWriteIdx {
            if let tempPtr = (arrayPtr+tempIdx).pointee {
                let tempItem: T = tempPtr
                if closure(tempItem) {
                    let _: T = tempPtr
                    (arrayPtr+tempIdx).pointee = nil
                    
                    // fill in the nil spot so we don't leave any holes
                    var fillIdx = tempIdx
                    while fillIdx != readIdx {
                        let prevIdx = fillIdx == 0 ? arraySize - 1 : (fillIdx - 1) % arraySize
                        (arrayPtr+fillIdx).pointee = (arrayPtr+prevIdx).pointee
                        fillIdx = prevIdx
                    }
                    
                    (arrayPtr+readIdx).pointee = nil
                    readIdx = (readIdx + 1) % arraySize
                }
            }
            tempIdx = (tempIdx + 1) % arraySize
        }
        readLock?.unlock()
        return
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
        return elementPtr!
    }

    public func clear() {
        readLock?.lock()

        while let elementPtr = (arrayPtr+readIdx).pointee {
            let _: T = elementPtr
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
