//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

#if !PLATFORM_SUPPORTS_PONYRT

func bridge<T: AnyObject>(obj: T) -> UnsafeRawPointer {
    return UnsafeRawPointer(Unmanaged.passRetained(obj).toOpaque())
}

func bridge<T: AnyObject>(ptr: UnsafeRawPointer) -> T {
    return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
}

public class Queue<T: AnyObject> {
    // safe only so long as there is one consumer and multiple producers
    private var arraySize: Int = 0
    private var arrayPtr: UnsafeMutablePointer<UnsafeRawPointer?>
    private var writeIdx = 0
    private var readIdx = 0

    private var readLock = NSLock()
    private var writeLock = NSLock()

    public init(_ size: Int) {
        arraySize = size
        arrayPtr = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: arraySize)
        arrayPtr.initialize(repeating: nil, count: arraySize)
    }

    public var isEmpty: Bool {
        return writeIdx == readIdx
    }

    public var isFull: Bool {
        return nextIndex(writeIdx, arraySize) == readIdx
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
        readLock.lock()

        let oldArraySize = arraySize
        arraySize *= 2
        let newArrayPtr = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: arraySize)
        newArrayPtr.initialize(repeating: nil, count: arraySize)

        var oldReadIdx = readIdx
        var newWriteIdx = 0
        while oldReadIdx != writeIdx {
            (newArrayPtr+newWriteIdx).pointee = (arrayPtr+oldReadIdx).pointee
            oldReadIdx = nextIndex(oldReadIdx, oldArraySize)
            newWriteIdx += 1
        }

        arrayPtr.deallocate()
        arrayPtr = newArrayPtr
        writeIdx = newWriteIdx
        readIdx = 0

        readLock.unlock()
        //print("grow[\(arraySize)]  \(readIdx) // \(writeIdx)")
    }

    private func nextIndex(_ idx: Int, _ size: Int) -> Int {
        return (idx + 1) % size
    }

    @discardableResult
    public func enqueue(_ element: T) -> Bool {
        writeLock.lock()

        let wasEmpty = isEmpty
        while isFull {
            grow()
        }

        let elementPtr = bridge(obj: element)
        //print("enqueue[\(writeIdx)]  \(elementPtr)")

        (arrayPtr+writeIdx).pointee = elementPtr
        writeIdx = nextIndex(writeIdx, arraySize)

        writeLock.unlock()

        return wasEmpty
    }

    public func dequeue() -> T? {
        readLock.lock()

        let elementPtr = (arrayPtr+readIdx).pointee
        if elementPtr == nil {
            readLock.unlock()
            return nil
        }
        //print("dequeue[\(readIdx)]  \(elementPtr!)")

        (arrayPtr+readIdx).pointee = nil
        readIdx = nextIndex(readIdx, arraySize)

        readLock.unlock()

        return bridge(ptr: elementPtr!)
    }

    public func markEmpty() -> Bool {
        writeLock.lock()
        readLock.lock()
        let wasEmpty = isEmpty
        readLock.unlock()
        writeLock.unlock()
        return wasEmpty
    }
}

#endif
