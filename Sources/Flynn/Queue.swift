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
    private var arraySize: Int = 0
    private var arrayPtr: UnsafeMutablePointer<UnsafeRawPointer?>
    private var writeIdx = 0
    private var readIdx = 0

    private var readLock = pthread_mutex_t()
    private var writeLock = pthread_mutex_t()

    public init(_ size: Int) {
        arraySize = size
        arrayPtr = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: arraySize)
        arrayPtr.initialize(repeating: nil, count: arraySize)

        pthread_mutex_init(&readLock, nil)
        pthread_mutex_init(&writeLock, nil)
    }

    deinit {
        clear()
        arrayPtr.deallocate()

        pthread_mutex_destroy(&readLock)
        pthread_mutex_destroy(&writeLock)
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
        pthread_mutex_lock(&readLock)

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

        pthread_mutex_unlock(&readLock)
        //print("grow[\(arraySize)]  \(readIdx) // \(writeIdx)")
    }

    private func nextIndex(_ idx: Int, _ size: Int) -> Int {
        return (idx + 1) % size
    }

    @discardableResult
    public func enqueue(_ element: T) -> Bool {
        pthread_mutex_lock(&writeLock)

        let wasEmpty = isEmpty
        while isFull {
            grow()
        }

        let elementPtr = bridge(obj: element)
        //print("enqueue[\(writeIdx)]  \(elementPtr)")

        (arrayPtr+writeIdx).pointee = elementPtr
        writeIdx = nextIndex(writeIdx, arraySize)

        pthread_mutex_unlock(&writeLock)

        return wasEmpty
    }

    @discardableResult
    public func dequeue() -> T? {
        pthread_mutex_lock(&readLock)

        let elementPtr = (arrayPtr+readIdx).pointee
        if elementPtr == nil {
            pthread_mutex_unlock(&readLock)
            return nil
        }
        //print("dequeue[\(readIdx)]  \(elementPtr!)")

        (arrayPtr+readIdx).pointee = nil
        readIdx = nextIndex(readIdx, arraySize)

        pthread_mutex_unlock(&readLock)
        return bridge(ptr: elementPtr!)
    }

    public func peek() -> T? {
        pthread_mutex_lock(&readLock)
        let elementPtr = (arrayPtr+readIdx).pointee
        if elementPtr == nil {
            pthread_mutex_unlock(&readLock)
            return nil
        }
        pthread_mutex_unlock(&readLock)
        return bridgePeek(ptr: elementPtr!)
    }

    public func clear() {
        pthread_mutex_lock(&readLock)

        while let elementPtr = (arrayPtr+readIdx).pointee {
            let _: T = bridge(ptr: elementPtr)
            (arrayPtr+readIdx).pointee = nil
            readIdx = nextIndex(readIdx, arraySize)
        }

        pthread_mutex_unlock(&readLock)
    }

    public func markEmpty() -> Bool {
        pthread_mutex_lock(&writeLock)
        pthread_mutex_lock(&readLock)
        let wasEmpty = isEmpty
        pthread_mutex_unlock(&readLock)
        pthread_mutex_unlock(&writeLock)
        return wasEmpty
    }
}
