//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

#if !PLATFORM_SUPPORTS_PONYRT

class Queue<T> {
    // concurrently safe only so long as there is one consumer and multiple producers
    fileprivate var arraySize = 512
    fileprivate var array = [T?](repeating: nil, count: 512)
    fileprivate var writeIdx = 0
    fileprivate var readIdx = 0
    fileprivate var readLock = NSLock()

    public var isEmpty: Bool {
        readLock.lock()
        let wasEmpty = (writeIdx == readIdx)
        readLock.unlock()
        return wasEmpty
    }

    public var isFull: Bool {
        readLock.lock()
        let wasFull = (nextIndex(writeIdx, arraySize) == readIdx)
        readLock.unlock()
        return wasFull
    }

    public var count: Int {
        readLock.lock()
        defer { readLock.unlock() }

        if writeIdx == readIdx {
            return 0
        }
        if writeIdx > readIdx {
            return writeIdx - readIdx
        }
        return arraySize - (readIdx - writeIdx)
    }

    public func grow() {
        let oldSize = arraySize
        arraySize *= 2
        var newArray = [T?](repeating: nil, count: arraySize)

        var oldReadIdx = readIdx
        var newWriteIdx = 0
        while oldReadIdx != writeIdx {
            newArray[newWriteIdx] = array[oldReadIdx]
            oldReadIdx = nextIndex(oldReadIdx, oldSize)
            newWriteIdx += 1
        }

        array = newArray
        writeIdx = newWriteIdx
        readIdx = 0

        //print("grow[\(arraySize)]  \(readIdx) // \(writeIdx)")
    }

    private func nextIndex(_ idx: Int, _ size: Int) -> Int {
        return (idx + 1) % size
    }

    @discardableResult
    public func enqueue(_ element: T) -> Bool {
        readLock.lock()
        let wasEmpty = (writeIdx == readIdx)

        while nextIndex(writeIdx, arraySize) == readIdx {
            grow()
        }

        //print("enqueue[\(writeIdx)]  \(element)")
        array[writeIdx] = element
        writeIdx = nextIndex(writeIdx, arraySize)
        readLock.unlock()
        return wasEmpty
    }

    public func markEmpty() -> Bool {
        readLock.lock()
        let wasEmpty = (writeIdx == readIdx)
        readLock.unlock()
        return wasEmpty
    }

    public func dequeue() -> T? {
        if isEmpty {
            return nil
        }

        readLock.lock()
        let element = array[readIdx]
        array[readIdx] = nil
        readIdx = nextIndex(readIdx, arraySize)
        readLock.unlock()
        return element
    }
}

#endif
