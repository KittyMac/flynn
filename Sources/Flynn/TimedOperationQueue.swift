import Foundation

// Wrapper around OperationQueue, but allows the following:
// - ability to force cancel infinite looping operations
// - ability to provide a timeout for operations (and cancelling when exceeding said timeout)
// - ability to provide a retry which preserves the order of queued operations
//
// Concurrency model:
// - A single NSLock (`lock`) guards `waiting` and `executing`.
// - Callbacks from inside the BlockOperation NEVER run while `lock` is held
//   by `advance()`: we release the lock before starting operations.
// - State transitions (retry-requeue and finished-remove) happen atomically
//   under a single lock acquisition to eliminate the race where the same
//   TimedOperation could end up in both `waiting` and `executing`.

private final class TimedOperation: Equatable {
    static func == (lhs: TimedOperation, rhs: TimedOperation) -> Bool {
        return lhs === rhs
    }

    let block: (Int) -> Bool
    let timeout: TimeInterval?

    // Retries remaining. Mutated only under TimedOperationQueue.lock.
    var retry: Int

    // Monotonic execution deadline (set when the op begins running).
    // Using a deadline instead of "now - start > timeout" avoids repeated
    // Date() allocations in the watcher loop.
    var deadline: TimeInterval? = nil

    // The underlying Operation. Mutated only under TimedOperationQueue.lock.
    weak var operation: Operation? = nil

    init(timeout: TimeInterval?,
         retry: Int,
         block: @escaping (Int) -> Bool) {
        self.retry = retry
        if let timeout = timeout,
           timeout > 0 {
            self.timeout = timeout
        } else {
            self.timeout = nil
        }
        self.block = block
    }
}

private struct WeakTimedOperationQueue {
    weak var queue: TimedOperationQueue?
}

public final class TimedOperationQueue {

    public var maxConcurrentOperationCount: Int {
        get {
            let v = operationQueue.maxConcurrentOperationCount
            return v >= 1 ? v : 1
        }
        set {
            operationQueue.maxConcurrentOperationCount = newValue
        }
    }

    private var waiting: [TimedOperation] = []
    private var executing: [TimedOperation] = []

    private let lock = NSLock()
    private let operationQueue = OperationQueue()

    // MARK: - Shared watcher thread for timeouts

    private static let staticLock = NSLock()
    private static var didBeginWatchThread = false
    private static var weakQueues: [WeakTimedOperationQueue] = []

    private static func register(_ queue: TimedOperationQueue) {
        staticLock.lock()
        weakQueues.append(WeakTimedOperationQueue(queue: queue))

        if !didBeginWatchThread {
            didBeginWatchThread = true
            Thread {
                Flynn.threadSetName("TimedOperationQueue")
                while true {
                    // Snapshot strong refs under the static lock, then release
                    // it before calling into each queue. This prevents the
                    // watcher from holding the static lock across per-queue
                    // work (which takes its own lock).
                    staticLock.lock()
                    var alive: [WeakTimedOperationQueue] = []
                    var strong: [TimedOperationQueue] = []
                    alive.reserveCapacity(weakQueues.count)
                    strong.reserveCapacity(weakQueues.count)
                    for entry in weakQueues {
                        if let q = entry.queue {
                            alive.append(entry)
                            strong.append(q)
                        }
                    }
                    weakQueues = alive
                    staticLock.unlock()

                    for q in strong {
                        q.checkTimeouts()
                    }

                    Flynn.usleep(500_000)
                }
            }.start()
        }
        staticLock.unlock()
    }

    public init() {
        TimedOperationQueue.register(self)
    }

    // MARK: - Public API

    public func addOperation(_ block: @escaping (Int) -> Bool) {
        enqueue(TimedOperation(timeout: nil, retry: 0, block: block))
    }

    public func addOperation(retry: Int,
                             _ block: @escaping (Int) -> Bool) {
        enqueue(TimedOperation(timeout: nil, retry: retry, block: block))
    }

    public func addOperation(timeout: TimeInterval?,
                             _ block: @escaping (Int) -> Bool) {
        enqueue(TimedOperation(timeout: timeout, retry: 0, block: block))
    }

    public func addOperation(timeout: TimeInterval?,
                             retry: Int,
                             _ block: @escaping (Int) -> Bool) {
        enqueue(TimedOperation(timeout: timeout, retry: retry, block: block))
    }

    public func waitUntilAllOperationsAreFinished() {
        while true {
            lock.lock()
            let done = waiting.isEmpty && executing.isEmpty
            lock.unlock()
            if done { return }
            Flynn.usleep(50_000)
        }
    }

    // MARK: - Internals

    private func enqueue(_ op: TimedOperation) {
        lock.lock()
        waiting.append(op)
        lock.unlock()
        advance()
    }

    /// Promote waiting ops into executing, up to `maxConcurrentOperationCount`.
    /// IMPORTANT: never hold `lock` while submitting to `operationQueue`.
    private func advance() {
        let max = maxConcurrentOperationCount

        // Collect ops to start, under the lock, then start them after unlocking.
        var toStart: [TimedOperation] = []

        lock.lock()
        while executing.count < max, !waiting.isEmpty {
            let next = waiting.removeFirst()
            executing.append(next)
            toStart.append(next)
        }
        lock.unlock()

        for op in toStart {
            start(op)
        }
    }

    private func start(_ op: TimedOperation) {
        let blockOp = BlockOperation { [weak self] in
            guard let self = self else { return }

            // Read retry count under the lock (may have been mutated).
            self.lock.lock()
            let attempt = op.retry
            self.lock.unlock()

            let succeeded = op.block(attempt)

            // Atomically update state: on failure with retries remaining,
            // move back to the front of `waiting`; otherwise drop from `executing`.
            self.lock.lock()
            if let idx = self.executing.firstIndex(where: { $0 === op }) {
                self.executing.remove(at: idx)
            }
            op.operation = nil
            op.deadline = nil
            if !succeeded && op.retry > 0 {
                op.retry -= 1
                self.waiting.insert(op, at: 0)
            }
            self.lock.unlock()

            self.advance()
        }

        // Record deadline + operation handle under the lock so the watcher
        // thread sees a consistent view.
        lock.lock()
        op.operation = blockOp
        if let timeout = op.timeout {
            // ProcessInfo.systemUptime is monotonic and cheap.
            op.deadline = ProcessInfo.processInfo.systemUptime + timeout
        }
        lock.unlock()

        operationQueue.addOperation(blockOp)
    }

    /// Called by the shared watcher thread. Cancels any ops past their deadline.
    /// Cancelled ops are treated as a "failed" completion: they retry if they
    /// have retries left, otherwise they're dropped. We rely on the BlockOperation's
    /// completion path (which still runs after cancel) to handle bookkeeping —
    /// except BlockOperation.cancel() doesn't interrupt the running block, so
    /// we must do the bookkeeping here for ops whose block is stuck.
    fileprivate func checkTimeouts() {
        let now = ProcessInfo.processInfo.systemUptime

        var timedOut: [TimedOperation] = []

        lock.lock()
        // Scan in reverse so removals don't shift indices we still need.
        for idx in stride(from: executing.count - 1, through: 0, by: -1) {
            let op = executing[idx]
            guard let deadline = op.deadline, now > deadline else { continue }

            // Cancel the underlying operation (best-effort; won't interrupt
            // a synchronous block, but prevents it running if not yet started).
            op.operation?.cancel()
            op.operation = nil
            op.deadline = nil
            executing.remove(at: idx)

            if op.retry > 0 {
                op.retry -= 1
                waiting.insert(op, at: 0)
            }
            timedOut.append(op)
        }
        lock.unlock()

        if !timedOut.isEmpty {
            advance()
        }
    }
}
