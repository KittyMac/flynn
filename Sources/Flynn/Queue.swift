import Foundation

public class Queue<T: AnyObject> {
    // safe only so long as there is one consumer and multiple producers

    @usableFromInline
    var arraySize: Int = 0

    private var arrayPtr: UnsafeMutablePointer<T?>

    @usableFromInline
    var writeIdx = 0

    @usableFromInline
    var readIdx = 0

    private var readLock = NSLock()
    private var writeLock = NSLock()

    private let manyProducers: Bool
    private let manyConsumers: Bool

    @usableFromInline
    var underPressure = false

    public init(size: Int,
                manyProducers: Bool = true,
                manyConsumers: Bool = true) {

        arraySize = size
        arrayPtr = UnsafeMutablePointer<T?>.allocate(capacity: arraySize)
        arrayPtr.initialize(repeating: nil, count: arraySize)

        self.manyProducers = manyProducers
        self.manyConsumers = manyConsumers
    }

    deinit {
        clear()
        arrayPtr.deallocate()
    }

    @inlinable
    public var isEmpty: Bool {
        return writeIdx == readIdx
    }

    @inlinable
    public var isFull: Bool {
        return ((writeIdx &+ 1) % arraySize) == readIdx
    }

    @inlinable
    public func checkPressure() {
        underPressure = count > (arraySize * 3 / 4)
    }

    public func dump() {
        print("Queue \(self)")
        print("count: \(count)")
        print("isEmpty: \(isEmpty)")

        let readElement = (arrayPtr + readIdx).pointee
        let writeElement = (arrayPtr + writeIdx).pointee
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
            return localWriteIdx &- localReadIdx
        }
        return arraySize &- (localReadIdx &- localWriteIdx)
    }

    public var capacity: Int {
        return arraySize
    }

    private func grow() {
        // Called with writeLock already held. Acquire readLock unconditionally
        // to safely relocate elements while no dequeue can be in progress.
        readLock.lock()

        let oldArraySize = arraySize
        let newArraySize = arraySize * 2
        let newArrayPtr = UnsafeMutablePointer<T?>.allocate(capacity: newArraySize)
        newArrayPtr.initialize(repeating: nil, count: newArraySize)

        var oldReadIdx = readIdx
        var newWriteIdx = 0
        while oldReadIdx != writeIdx {
            (newArrayPtr + newWriteIdx).initialize(to: (arrayPtr + oldReadIdx).move())
            oldReadIdx = (oldReadIdx &+ 1) % oldArraySize
            newWriteIdx &+= 1
        }

        // Clear remaining slots that weren't moved (already nil, just deinit)
        for i in 0..<oldArraySize {
            // Only deinitialize slots that weren't moved from
            // (moved-from slots are already consumed by .move())
        }
        arrayPtr.deallocate()

        arrayPtr = newArrayPtr
        arraySize = newArraySize
        writeIdx = newWriteIdx
        readIdx = 0

        readLock.unlock()
    }

    @discardableResult
    public func enqueue(_ element: T) -> Bool {
        let useWriteLock = manyProducers || underPressure

        if useWriteLock { writeLock.lock() }

        let wasEmpty = (writeIdx == readIdx)
        while isFull {
            grow()
        }

        (arrayPtr + writeIdx).pointee = element
        writeIdx = (writeIdx &+ 1) % arraySize

        checkPressure()

        if useWriteLock { writeLock.unlock() }

        return wasEmpty
    }

    @discardableResult
    public func enqueue(_ element: T, sortedBy closure: (T, T) -> Bool) -> Bool {
        writeLock.lock()

        let wasEmpty = (writeIdx == readIdx)
        while isFull {
            grow()
        }

        readLock.lock()

        var idx = readIdx
        while idx != writeIdx {
            if let existingElement = (arrayPtr + idx).pointee {
                if closure(existingElement, element) {
                    // Insert here and shift everything after it down by one.
                    var bubble: T? = element
                    var shiftIdx = idx
                    while shiftIdx != writeIdx {
                        let temp = (arrayPtr + shiftIdx).pointee
                        (arrayPtr + shiftIdx).pointee = bubble
                        bubble = temp
                        shiftIdx = (shiftIdx &+ 1) % arraySize
                    }
                    (arrayPtr + writeIdx).pointee = bubble
                    writeIdx = (writeIdx &+ 1) % arraySize

                    checkPressure()

                    readLock.unlock()
                    writeLock.unlock()
                    return wasEmpty
                }
            }
            idx = (idx &+ 1) % arraySize
        }

        (arrayPtr + writeIdx).pointee = element
        writeIdx = (writeIdx &+ 1) % arraySize

        checkPressure()

        readLock.unlock()
        writeLock.unlock()

        return wasEmpty
    }

    @discardableResult
    public func dequeue() -> T? {
        let useReadLock = manyConsumers || underPressure

        if useReadLock { readLock.lock() }

        let elementPtr = (arrayPtr + readIdx).pointee
        if elementPtr == nil {
            if useReadLock { readLock.unlock() }
            return nil
        }

        (arrayPtr + readIdx).pointee = nil
        readIdx = (readIdx &+ 1) % arraySize

        checkPressure()

        if useReadLock { readLock.unlock() }
        return elementPtr
    }

    @discardableResult
    public func dequeueIf(_ closure: (T) -> Bool) -> T? {
        let useReadLock = manyConsumers || underPressure

        if useReadLock { readLock.lock() }

        guard let element = (arrayPtr + readIdx).pointee else {
            if useReadLock { readLock.unlock() }
            return nil
        }

        if closure(element) {
            (arrayPtr + readIdx).pointee = nil
            readIdx = (readIdx &+ 1) % arraySize
            if useReadLock { readLock.unlock() }
            return element
        }

        if useReadLock { readLock.unlock() }
        return nil
    }

    public func  dequeueAny(_ closure: (T) -> Bool) {
        let useReadLock = manyConsumers || underPressure

        if useReadLock { readLock.lock() }

        guard (arrayPtr + readIdx).pointee != nil else {
            if useReadLock { readLock.unlock() }
            return
        }

        var tempIdx = readIdx
        let savedWriteIdx = writeIdx
        while tempIdx != savedWriteIdx {
            if let element = (arrayPtr + tempIdx).pointee {
                if closure(element) {
                    (arrayPtr + tempIdx).pointee = nil

                    // Shift elements toward the read side to fill the hole
                    var fillIdx = tempIdx
                    while fillIdx != readIdx {
                        let prevIdx = fillIdx == 0 ? arraySize &- 1 : fillIdx &- 1
                        (arrayPtr + fillIdx).pointee = (arrayPtr + prevIdx).pointee
                        (arrayPtr + prevIdx).pointee = nil
                        fillIdx = prevIdx
                    }

                    readIdx = (readIdx &+ 1) % arraySize
                }
            }
            tempIdx = (tempIdx &+ 1) % arraySize
        }
        if useReadLock { readLock.unlock() }
    }

    public func peek() -> T? {
        if manyConsumers {
            fatalError("Queues which allow multiple consumers cannot use peek() safely")
        }
        if writeIdx == readIdx {
            return nil
        }

        let useReadLock = underPressure

        if useReadLock { readLock.lock() }
        let elementPtr = (arrayPtr + readIdx).pointee
        if useReadLock { readLock.unlock() }
        return elementPtr
    }

    public func clear() {
        let useReadLock = manyConsumers || underPressure

        if useReadLock { readLock.lock() }

        while (arrayPtr + readIdx).pointee != nil {
            (arrayPtr + readIdx).pointee = nil
            readIdx = (readIdx &+ 1) % arraySize
        }

        if useReadLock { readLock.unlock() }
    }

    public func markEmpty() -> Bool {
        let useReadLock = manyConsumers || underPressure
        let useWriteLock = manyProducers || underPressure

        if useWriteLock { writeLock.lock() }
        if useReadLock { readLock.lock() }
        let wasEmpty = (writeIdx == readIdx)
        if useReadLock { readLock.unlock() }
        if useWriteLock { writeLock.unlock() }
        return wasEmpty
    }
}
