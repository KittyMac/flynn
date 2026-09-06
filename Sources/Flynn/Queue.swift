import Foundation

internal class Queue<T: AnyObject> {
    // safe only so long as there is one consumer and multiple producers
    
    // readIdx is owned by the consumer (guarded by readLock) and writeIdx by
    // the producer (guarded by writeLock), but each side deliberately reads the
    // OTHER side's index without taking that lock -- isEmpty, isFull, count,
    // dequeueIf's early-out and dequeueAny's savedWriteIdx all do this. The
    // algorithm tolerates a stale value, so the fix is atomic storage rather
    // than more locking. arraySize and underPressure are likewise written under
    // lock and read without one.
    @usableFromInline
    let arraySizeAtomic = AtomicInt(0)
    @usableFromInline
    var arraySize: Int {
        get { return arraySizeAtomic.value }
        set { arraySizeAtomic.value = newValue }
    }

    private var arrayPtr: UnsafeMutablePointer<T?>

    @usableFromInline
    let writeIdxAtomic = AtomicInt(0)
    @usableFromInline
    var writeIdx: Int {
        get { return writeIdxAtomic.value }
        set { writeIdxAtomic.value = newValue }
    }

    @usableFromInline
    let readIdxAtomic = AtomicInt(0)
    @usableFromInline
    var readIdx: Int {
        get { return readIdxAtomic.value }
        set { readIdxAtomic.value = newValue }
    }

    private var readLock = NSLock()
    private var writeLock = NSLock()

    private let manyProducers: Bool
    private let manyConsumers: Bool

    @usableFromInline
    let underPressureAtomic = AtomicBool(false)
    @usableFromInline
    var underPressure: Bool {
        get { return underPressureAtomic.value }
        set { underPressureAtomic.value = newValue }
    }

    public init(size: Int,
                manyProducers: Bool = true,
                manyConsumers: Bool = true) {

        arrayPtr = UnsafeMutablePointer<T?>.allocate(capacity: size)
        arrayPtr.initialize(repeating: nil, count: size)

        self.manyProducers = manyProducers
        self.manyConsumers = manyConsumers

        // arraySize is a computed property over atomic storage, so it can only
        // be assigned once every stored property is initialized.
        arraySize = size
    }

    deinit {
        clear()
        arrayPtr.deallocate()
        //print("deinit - Queue")
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
        print("cout: \(count)")
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
        let useReadLock = manyConsumers || underPressure

        if useReadLock { readLock.lock() }

        let oldArraySize = arraySize
        arraySize *= 2
        let newArrayPtr = UnsafeMutablePointer<T?>.allocate(capacity: arraySize)
        newArrayPtr.initialize(repeating: nil, count: arraySize)

        var oldReadIdx = readIdx
        var newWriteIdx = 0
        while oldReadIdx != writeIdx {
            (newArrayPtr+newWriteIdx).pointee = (arrayPtr+oldReadIdx).pointee
            oldReadIdx = (oldReadIdx &+ 1) % oldArraySize
            newWriteIdx &+= 1
        }

        arrayPtr.deinitialize(count: oldArraySize)
        arrayPtr.deallocate()
        arrayPtr = newArrayPtr
        writeIdx = newWriteIdx
        readIdx = 0

        if useReadLock { readLock.unlock() }
        //print("grow[\(arraySize)]  \(readIdx) // \(writeIdx)")
    }

    @discardableResult
    public func enqueue(_ element: T) -> Bool {
        let useWriteLock = manyProducers || underPressure

        if useWriteLock { writeLock.lock() }

        let wasEmpty = (writeIdx == readIdx)
        while underPressure && isFull {
            grow()
        }

        //print("enqueue[\(writeIdx)]  \(elementPtr)")

        (arrayPtr+writeIdx).pointee = element
        writeIdx = (writeIdx &+ 1) % arraySize

        checkPressure()

        if useWriteLock { writeLock.unlock() }

        return wasEmpty
    }

    @discardableResult
    public func enqueue(_ element: T, sortedBy closure: (T, T) -> Bool) -> Bool {
        // NOTE: ALL LOCKS ARE ALWAYS REQUIRED IN THIS FUNCTION

        writeLock.lock()

        let wasEmpty = (writeIdx == readIdx)
        while underPressure && isFull {
            grow()
        }

        // for sorted enqueuing, we need to capture the read lock and then
        // insert our new item in the correct spot.
        readLock.lock()

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
                        idx = (idx &+ 1) % arraySize
                    }
                    (arrayPtr+writeIdx).pointee = bubble
                    writeIdx = (writeIdx &+ 1) % arraySize

                    checkPressure()

                    readLock.unlock()
                    writeLock.unlock()
                    return wasEmpty
                }
            }
            idx = (idx &+ 1) % arraySize
        }

        (arrayPtr+writeIdx).pointee = element
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

        let elementPtr = (arrayPtr+readIdx).pointee
        if elementPtr == nil {
            if useReadLock { readLock.unlock() }
            return nil
        }
        //print("dequeue[\(readIdx)]  \(elementPtr!)")

        (arrayPtr+readIdx).pointee = nil
        readIdx = (readIdx &+ 1) % arraySize

        checkPressure()

        if useReadLock { readLock.unlock() }
        return elementPtr!
    }

    @discardableResult
    public func dequeueIf(_ closure: (T) -> Bool) -> T? {
        if writeIdx == readIdx {
            return nil
        }

        let useReadLock = manyConsumers || underPressure

        if useReadLock { readLock.lock() }
        let elementPtr = (arrayPtr+readIdx).pointee
        if elementPtr == nil {
            if useReadLock { readLock.unlock() }
            return nil
        }

        let item: T = elementPtr!
        if closure(item) {
            (arrayPtr+readIdx).pointee = nil
            readIdx = (readIdx &+ 1) % arraySize
            let element: T = elementPtr!
            if useReadLock { readLock.unlock() }
            return element
        }

        if useReadLock { readLock.unlock() }
        return nil
    }

    public func dequeueAny(_ closure: (T) -> Bool) {
        if writeIdx == readIdx {
            return
        }

        let useReadLock = manyConsumers || underPressure

        if useReadLock { readLock.lock() }
        let elementPtr = (arrayPtr+readIdx).pointee
        if elementPtr == nil {
            if useReadLock { readLock.unlock() }
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
                        let prevIdx = fillIdx == 0 ? arraySize &- 1 : (fillIdx &- 1) % arraySize
                        (arrayPtr+fillIdx).pointee = (arrayPtr+prevIdx).pointee
                        fillIdx = prevIdx
                    }

                    (arrayPtr+readIdx).pointee = nil
                    readIdx = (readIdx &+ 1) % arraySize
                }
            }
            tempIdx = (tempIdx &+ 1) % arraySize
        }
        if useReadLock { readLock.unlock() }
        return
    }

    public func peek() -> T? {
        if manyConsumers {
            fatalError("Queues which allow multiple consumers cannot use peek() safely")
        }
        if writeIdx == readIdx {
            return nil
        }

        let useReadLock = manyConsumers || underPressure

        if useReadLock { readLock.lock() }
        let elementPtr = (arrayPtr+readIdx).pointee
        if elementPtr == nil {
            readLock.unlock()
            return nil
        }
        if useReadLock { readLock.unlock() }
        return elementPtr!
    }

    public func clear() {
        let useReadLock = manyConsumers || underPressure

        if useReadLock { readLock.lock() }

        while let elementPtr = (arrayPtr+readIdx).pointee {
            let _: T = elementPtr
            (arrayPtr+readIdx).pointee = nil
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
