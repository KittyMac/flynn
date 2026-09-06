import Foundation

// Wrapper around OperationQueue, but allows the following:
// - ability to force cancel infinite looping operations
// - ability to provide a timeout for operations (and cancelling when exceeding said timeout)
// - ability to provide a retry which preserves the order of queued operations

private class TimedOperation: Equatable {
    static func == (lhs: TimedOperation, rhs: TimedOperation) -> Bool {
        return lhs.uuid == rhs.uuid
    }
    
    let uuid = UUID().uuidString
    
    let block: (Int) -> Bool
    let timeout: TimeInterval?
    
    var retry: Int
    
    // executionDate and operation are written by the BlockOperation body on an
    // OperationQueue worker thread, and read/written by shouldTimeout() on
    // whichever thread is inside TimedOperationQueue.advance(). The queue's own
    // lock does not cover the worker, so these need their own.
    private let fieldsLock = NSLock()
    private var _executionDate: Date?
    private var _operation: Operation?
    
    var executionDate: Date? {
        get { fieldsLock.lock(); defer { fieldsLock.unlock() }; return _executionDate }
        set { fieldsLock.lock(); _executionDate = newValue; fieldsLock.unlock() }
    }
    var operation: Operation? {
        get { fieldsLock.lock(); defer { fieldsLock.unlock() }; return _operation }
        set { fieldsLock.lock(); _operation = newValue; fieldsLock.unlock() }
    }
    
    init(timeout: TimeInterval?,
         retry: Int,
         block: @escaping (Int) -> Bool) {
        self.retry = retry
        self.timeout = timeout
        self.block = block
    }
    
    func start(operationQueue: OperationQueue,
               retry: @escaping () -> (), finished: @escaping () -> ()) {
        
        let blockOperation = BlockOperation {
            self.executionDate = Date()
            if self.block(self.retry) == false {
                retry()
            }
            finished()
            self.operation = nil
        }
        operation = blockOperation
        
        operationQueue.addOperation(blockOperation)
    }
    func shouldTimeout(operationQueue: OperationQueue) -> Bool {
        fieldsLock.lock()
        guard let executionDate = _executionDate,
              let timeout = timeout,
              abs(executionDate.timeIntervalSinceNow) > timeout else {
            fieldsLock.unlock()
            return false
        }
        let operation = _operation
        _operation = nil
        fieldsLock.unlock()
        
        // cancel() outside the lock; it is not ours and may call back.
        operation?.cancel()
        return true
    }
}

private struct WeakTimedOperationQueue {
    weak var timedOperationQueue: TimedOperationQueue?
}

public class TimedOperationQueue {
    
    public var maxConcurrentOperationCount: Int {
        get {
            if operationQueue.maxConcurrentOperationCount >= 1 {
                return operationQueue.maxConcurrentOperationCount
            }
            return 1
        }
        set {
            operationQueue.maxConcurrentOperationCount = newValue
        }
    }
    
    private var waiting: [TimedOperation] = []
    private var executing: [TimedOperation] = []
    // Read by count()/waitingCount()/activeCount() without taking `lock`, and
    // written under `lock` by advance()/addOperation(). The unlocked read is
    // deliberate -- callers only want a snapshot -- so these are atomics rather
    // than lock-protected plain Ints.
    private let _waitingCount = AtomicInt(0)
    private let _activeCount = AtomicInt(0)
    
    private let lock = NSLock()
    
    private let operationQueue = OperationQueue()
    
    private static var didBeginWatchThread = false
    private static let staticLock = NSLock()
    private static var weakTimedOperationQueues: [WeakTimedOperationQueue] = []
    private static func register(_ timedOperationQueue: TimedOperationQueue) {
        staticLock.lock()
        weakTimedOperationQueues.append(
            WeakTimedOperationQueue(timedOperationQueue: timedOperationQueue)
        )
        
        if didBeginWatchThread == false {
            didBeginWatchThread = true
            Thread {
                Flynn.threadSetName("TimedOperationQueue")
                while true {
                    
                    staticLock.lock()
                    weakTimedOperationQueues = weakTimedOperationQueues.filter {
                        $0.timedOperationQueue?.advance()
                        return $0.timedOperationQueue != nil
                    }
                    staticLock.unlock()
                                        
                    Flynn.usleep(500_000)
                }
            }.start()
        }
        staticLock.unlock()
    }
    
    public init() {
        TimedOperationQueue.register(self)
    }
    
    public func count() -> Int {
        return _waitingCount.value + _activeCount.value
    }
    
    public func waitingCount() -> Int {
        return _waitingCount.value
    }
    
    public func activeCount() -> Int {
        return _activeCount.value
    }
    
    public func addOperation(retry: Int,
                             _ block: @escaping (Int) -> Bool) {
        lock.lock()

        waiting.append(TimedOperation(timeout: nil,
                                      retry: retry,
                                      block: block))
        _waitingCount.value = waiting.count
        _activeCount.value = executing.count
        lock.unlock()
        
        advance()
    }
    
    public func addOperation(timeout: TimeInterval,
                             retry: Int,
                             _ block: @escaping (Int) -> Bool) {
        lock.lock()

        waiting.append(TimedOperation(timeout: timeout,
                                      retry: retry,
                                      block: block))
        _waitingCount.value = waiting.count
        _activeCount.value = executing.count
        lock.unlock()
        
        advance()
    }
    
    public func addOperation(timeout: TimeInterval,
                             _ block: @escaping (Int) -> Bool) {
        lock.lock()

        waiting.append(TimedOperation(timeout: timeout,
                                      retry: 0,
                                      block: block))
        _waitingCount.value = waiting.count
        _activeCount.value = executing.count
        lock.unlock()
        
        advance()
    }
    
    public func addOperation(_ block: @escaping (Int) -> (Bool)) {
        lock.lock()
        
        waiting.append(TimedOperation(timeout: nil,
                                      retry: 0,
                                      block: block))
        _waitingCount.value = waiting.count
        _activeCount.value = executing.count
        lock.unlock()
        
        advance()
    }
    
    fileprivate func advance() {
        lock.lock()
                
        for idx in stride(from: executing.count-1, through: 0, by: -1) {
            let operation = executing[idx]
            if operation.shouldTimeout(operationQueue: operationQueue) {
                executing.remove(at: idx)
                _waitingCount.value = waiting.count
                _activeCount.value = executing.count
            }
        }
        
        while executing.count < maxConcurrentOperationCount && waiting.count > 0 {
            let next = waiting.removeFirst()
            executing.append(next)
            _waitingCount.value = waiting.count
            _activeCount.value = executing.count
            
            next.start(operationQueue: operationQueue) { [weak self] in
                guard let self = self else { return }
                
                self.lock.lock()
                if next.retry > 0 {
                    next.retry -= 1
                    self.waiting.insert(next, at: 0)
                }
                self._waitingCount.value = self.waiting.count
                self._activeCount.value = self.executing.count
                self.lock.unlock()
                
                self.advance()
            } finished: { [weak self] in
                guard let self = self else { return }
                
                self.lock.lock()
                if let index = self.executing.firstIndex(of: next) {
                    self.executing.remove(at: index)
                }
                self._waitingCount.value = self.waiting.count
                self._activeCount.value = self.executing.count
                self.lock.unlock()
                
                self.advance()
            }
        }
        
        _waitingCount.value = waiting.count
        _activeCount.value = executing.count
        lock.unlock()
    }
    
    public func waitUntilAllOperationsAreFinished() {
        var done = false
        while !done {
            lock.lock()
            done = waiting.count + executing.count <= 0
            lock.unlock()
            Flynn.usleep(50_000)
        }
    }
}
