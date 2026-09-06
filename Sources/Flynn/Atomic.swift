// flynn:ignore Access Level Violation: Unsafe functions should not be used

import Foundation
import Pony

// Minimal atomic storage for the handful of Flynn variables which are
// intentionally read by one thread while written by another.
//
// These are NOT locks and they do not make a multi-step operation atomic. They
// exist so that a deliberately-racy-but-tolerant read (a queue index, a cached
// count, a cancellation flag) is a well-defined atomic load rather than
// undefined behaviour. Where mutual exclusion is actually required, the
// surrounding NSLock is still doing that job.

@usableFromInline
internal final class AtomicInt {
    private let ptr: UnsafeMutablePointer<Int64>

    init(_ value: Int = 0) {
        ptr = UnsafeMutablePointer<Int64>.allocate(capacity: 1)
        ptr.initialize(to: Int64(value))
    }

    deinit {
        ptr.deinitialize(count: 1)
        ptr.deallocate()
    }

    @usableFromInline
    var value: Int {
        get { return Int(pony_atomic_load64(ptr)) }
        set { pony_atomic_store64(ptr, Int64(newValue)) }
    }

    @discardableResult
    @usableFromInline
    func add(_ delta: Int) -> Int {
        return Int(pony_atomic_add64(ptr, Int64(delta)))
    }
}

@usableFromInline
internal final class AtomicBool {
    private let ptr: UnsafeMutablePointer<Bool>

    init(_ value: Bool = false) {
        ptr = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
        ptr.initialize(to: value)
    }

    deinit {
        ptr.deinitialize(count: 1)
        ptr.deallocate()
    }

    @usableFromInline
    var value: Bool {
        get { return pony_atomic_load_bool(ptr) }
        set { pony_atomic_store_bool(ptr, newValue) }
    }
}

internal final class AtomicCondition {
    private let active = AtomicBool(false)
    private let lock = NSLock()

    func checkInactive(_ block: () -> Void) {
        if active.value { return }
        lock.lock()
        defer { lock.unlock() }
        if active.value == false {
            active.value = true
            block()
        }
    }

    func checkActive(_ block: () -> Void) {
        if active.value == false { return }
        lock.lock()
        defer { lock.unlock() }
        if active.value {
            block()
            active.value = false
        }
    }
}
