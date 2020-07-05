//
//  Actor.swift
//  Flynn
//
//  Created by Rocco Bowling on 5/10/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation

#if !PLATFORM_SUPPORTS_PONYRT

class Queue<T: AnyObject> {
    // safe only so long as there is one consumer and multiple producers
    private var arraySize: Int = 2048
    private var array = [T?](repeating: nil, count: 2048)
    private var writeIdx = 0
    private var readIdx = 0
    private var readLock = NSLock()
    private var markedEmpty: Bool = true

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
        let oldArraySize = arraySize
        arraySize *= 2
        var newArray = [T?](repeating: nil, count: arraySize)

        var oldReadIdx = readIdx
        var newWriteIdx = 0
        while oldReadIdx != writeIdx {
            newArray[newWriteIdx] = array[oldReadIdx]
            oldReadIdx = nextIndex(oldReadIdx, oldArraySize)
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

        let wasEmpty = isEmpty
        while isFull {
            grow()
        }
        //print("enqueue[\(writeIdx)]  \(element)")
        array[writeIdx] = element
        writeIdx = nextIndex(writeIdx, arraySize)
        readLock.unlock()

        return wasEmpty
    }

    public func dequeue() -> T? {
        readLock.lock()

        if isEmpty {
            readLock.unlock()
            return nil
        }

        let element = array[readIdx]
        array[readIdx] = nil
        readIdx = nextIndex(readIdx, arraySize)

        //print("dequeue[\(readIdx)]  \(element)")
        readLock.unlock()

        return element
    }

    public func markEmpty() -> Bool {
        readLock.lock()
        let wasEmpty = isEmpty
        readLock.unlock()
        return wasEmpty
    }
}

#endif
