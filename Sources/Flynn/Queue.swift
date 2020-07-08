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

    public init(_ size: Int,
                _ resizing: Bool = true,
                _ mulitpleProducers: Bool = true,
                _ multipleConsumers: Bool = true) {

        arrayResizing = resizing
        arraySize = size
        arrayPtr = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: arraySize)
        arrayPtr.initialize(repeating: nil, count: arraySize)

        // Note: if the queue cannot grow, and we have only one producer or one consumer
        // then we can get away with not having those specific locks
        if multipleConsumers || resizing {
            readLock = NSLock()
        }
        if mulitpleProducers || resizing {
            writeLock = NSLock()
        }
    }

    deinit {
        clear()
        arrayPtr.deallocate()
        //print("deinit - Queue")
    }

    @inline(__always)
    private func nextIndex(_ idx: Int, _ size: Int) -> Int {
        return (idx + 1) % size
    }

    @inline(__always)
    private func prevIndex(_ idx: Int, _ size: Int) -> Int {
        if idx <= 0 {
            return arraySize - 1
        }
        return idx - 1
    }

    @inline(__always)
    public var isEmpty: Bool {
        return writeIdx == readIdx
    }

    @inline(__always)
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
        readLock?.lock()

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

        readLock?.unlock()
        //print("grow[\(arraySize)]  \(readIdx) // \(writeIdx)")
    }

    @discardableResult
    public func enqueue(_ element: T) -> Bool {
        writeLock?.lock()

        let wasEmpty = isEmpty
        while isFull {
            if arrayResizing == false {
                writeLock?.unlock()
                return false
            }
            grow()
        }

        //print("enqueue[\(writeIdx)]  \(elementPtr)")

        (arrayPtr+writeIdx).pointee = bridge(obj: element)
        writeIdx = nextIndex(writeIdx, arraySize)

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
        readIdx = nextIndex(readIdx, arraySize)

        readLock?.unlock()
        return bridge(ptr: elementPtr!)
    }

    public func peek() -> T? {
        if isEmpty {
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

    public func steal() -> T? {
        if isEmpty == false {
            if writeLock?.try() ?? true {
                readLock?.lock()

                writeIdx = prevIndex(writeIdx, arraySize)
                let elementPtr = (arrayPtr+writeIdx).pointee
                if elementPtr == nil {
                    readLock?.unlock()
                    writeLock?.unlock()
                    return nil
                }
                (arrayPtr+writeIdx).pointee = nil

                readLock?.unlock()
                writeLock?.unlock()

                return bridge(ptr: elementPtr!)
            }
        }
        return nil
    }

    public func clear() {
        readLock?.lock()

        while let elementPtr = (arrayPtr+readIdx).pointee {
            let _: T = bridge(ptr: elementPtr)
            (arrayPtr+readIdx).pointee = nil
            readIdx = nextIndex(readIdx, arraySize)
        }

        readLock?.unlock()
    }

    public func markEmpty() -> Bool {
        writeLock?.lock()
        readLock?.lock()
        let wasEmpty = isEmpty
        readLock?.unlock()
        writeLock?.unlock()
        return wasEmpty
    }
}
