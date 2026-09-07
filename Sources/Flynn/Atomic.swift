// flynn:ignore Access Level Violation: Unsafe functions should not be used

import Foundation
import Pony

// Minimal atomic storage for the handful of variables which are intentionally
// read by one thread while written by another.
//
// The load/store accessors are NOT locks and they do not make a multi-step
// operation atomic. They exist so that a deliberately-racy-but-tolerant read (a
// queue index, a cached count, a cancellation flag) is a well-defined atomic
// load rather than undefined behaviour. Where mutual exclusion is actually
// required, the surrounding NSLock is still doing that job.
//
// `exchange` and `compareExchange` are different in kind: they are
// read-modify-write operations, and they do give you a correctness guarantee.
// Use them when a value has to be claimed exactly once by one of several
// threads -- releasing a file descriptor, firing a completion, arming a
// one-shot flag -- and the alternative would be a check-then-act sequence that
// two threads can both pass.

public final class AtomicInt {
    private let ptr: UnsafeMutablePointer<Int64>

    public init(_ value: Int = 0) {
        ptr = UnsafeMutablePointer<Int64>.allocate(capacity: 1)
        ptr.initialize(to: Int64(value))
    }

    deinit {
        ptr.deinitialize(count: 1)
        ptr.deallocate()
    }

    public var value: Int {
        get { return Int(pony_atomic_load64(ptr)) }
        set { pony_atomic_store64(ptr, Int64(newValue)) }
    }

    @discardableResult
    public func add(_ delta: Int) -> Int {
        return Int(pony_atomic_add64(ptr, Int64(delta)))
    }

    /// Stores `value` and returns what was there before, as one indivisible
    /// step. Exactly one concurrent caller can observe any given prior value.
    @discardableResult
    public func exchange(_ value: Int) -> Int {
        return Int(pony_atomic_exchange64(ptr, Int64(value)))
    }

    /// Stores `desired` only if the current value is still `expected`.
    /// Returns true if the store happened.
    @discardableResult
    public func compareExchange(expected: Int, desired: Int) -> Bool {
        var expected64 = Int64(expected)
        return pony_atomic_cas64(ptr, &expected64, Int64(desired))
    }
}

// Int32 rather than Int because the motivating values are natively 32 bits and
// are handed straight to C or to a syscall -- a file descriptor above all.
// Widening one of those to Int would mean the atomic slot and the value being
// guarded are two different objects, and the whole point is that they are one.
public final class AtomicInt32 {
    private let ptr: UnsafeMutablePointer<Int32>

    public init(_ value: Int32 = 0) {
        ptr = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        ptr.initialize(to: value)
    }

    deinit {
        ptr.deinitialize(count: 1)
        ptr.deallocate()
    }

    public var value: Int32 {
        get { return pony_atomic_load32(ptr) }
        set { pony_atomic_store32(ptr, newValue) }
    }

    @discardableResult
    public func add(_ delta: Int32) -> Int32 {
        return pony_atomic_add32(ptr, delta)
    }

    /// Stores `value` and returns what was there before, as one indivisible
    /// step. Exactly one concurrent caller can observe any given prior value.
    ///
    /// This is the operation that makes "close a file descriptor once" safe:
    ///
    ///     let fd = storage.exchange(-1)
    ///     guard fd >= 0 else { return }
    ///     _ = posix_close(fd)
    ///
    /// Two threads racing here cannot both come away with the same fd, so the
    /// descriptor cannot be closed twice and its number cannot be pulled out
    /// from under whoever the kernel has since reassigned it to.
    @discardableResult
    public func exchange(_ value: Int32) -> Int32 {
        return pony_atomic_exchange32(ptr, value)
    }

    /// Stores `desired` only if the current value is still `expected`.
    /// Returns true if the store happened.
    @discardableResult
    public func compareExchange(expected: Int32, desired: Int32) -> Bool {
        var expected32 = expected
        return pony_atomic_cas32(ptr, &expected32, desired)
    }
}

public final class AtomicBool {
    private let ptr: UnsafeMutablePointer<Bool>

    public init(_ value: Bool = false) {
        ptr = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
        ptr.initialize(to: value)
    }

    deinit {
        ptr.deinitialize(count: 1)
        ptr.deallocate()
    }

    public var value: Bool {
        get { return pony_atomic_load_bool(ptr) }
        set { pony_atomic_store_bool(ptr, newValue) }
    }

    /// Stores `value` and returns what was there before, as one indivisible
    /// step. `exchange(true) == false` identifies the single thread which
    /// claimed a one-shot flag.
    @discardableResult
    public func exchange(_ value: Bool) -> Bool {
        return pony_atomic_exchange_bool(ptr, value)
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
