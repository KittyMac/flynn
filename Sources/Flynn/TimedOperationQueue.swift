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
    
    let block: () -> Bool
    let timeout: TimeInterval?
    
    var retry: Int
    
    var executionDate: Date? = nil
    var operation: Operation? = nil
    
    init(timeout: TimeInterval?,
         retry: Int,
         block: @escaping () -> Bool) {
        self.retry = retry
        self.timeout = timeout
        self.block = block
    }
    
    func start(operationQueue: OperationQueue,
               retry: @escaping () -> (), finished: @escaping () -> ()) {
        
        let blockOperation = BlockOperation {
            self.executionDate = Date()
            if self.block() == false {
                retry()
            }
            finished()
        }
        operation = blockOperation
        
        operationQueue.addOperation(blockOperation)
    }
    func shouldTimeout(operationQueue: OperationQueue) -> Bool {
        if let executionDate = executionDate,
           let timeout = timeout,
           abs(executionDate.timeIntervalSinceNow) > timeout {
            operation?.cancel()
            return true
        }
        return false
    }
}

private struct WeakTimedOperationQueue {
    weak var timedOperationQueue: TimedOperationQueue?
}

public class TimedOperationQueue {
    
    public var maxConcurrentOperationCount: Int {
        get {
            return operationQueue.maxConcurrentOperationCount
        }
        set {
            operationQueue.maxConcurrentOperationCount = newValue
        }
    }
    
    private var waiting: [TimedOperation] = []
    private var executing: [TimedOperation] = []
    
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
    
    public func addOperation(retry: Int,
                             _ block: @escaping () -> Bool) {
        lock.lock()

        waiting.append(TimedOperation(timeout: nil,
                                      retry: retry,
                                      block: block))
        lock.unlock()
        
        advance()
    }
    
    public func addOperation(timeout: TimeInterval,
                             retry: Int,
                             _ block: @escaping () -> Bool) {
        lock.lock()

        waiting.append(TimedOperation(timeout: timeout,
                                      retry: retry,
                                      block: block))
        lock.unlock()
        
        advance()
    }
    
    public func addOperation(timeout: TimeInterval,
                             _ block: @escaping () -> Bool) {
        lock.lock()

        waiting.append(TimedOperation(timeout: timeout,
                                      retry: 0,
                                      block: block))
        lock.unlock()
        
        advance()
    }
    
    public func addOperation(_ block: @escaping () -> (Bool)) {
        lock.lock()
        
        waiting.append(TimedOperation(timeout: nil,
                                      retry: 0,
                                      block: block))
        lock.unlock()
        
        advance()
    }
    
    fileprivate func advance() {
        lock.lock()
                
        for idx in stride(from: executing.count-1, through: 0, by: -1) {
            let operation = executing[idx]
            if operation.shouldTimeout(operationQueue: operationQueue) {
                executing.remove(at: idx)
            }
        }
        
        while executing.count < maxConcurrentOperationCount && waiting.count > 0 {
            let next = waiting.removeFirst()
            executing.append(next)
            next.start(operationQueue: operationQueue) {
                self.lock.lock()
                if next.retry > 0 {
                    next.retry -= 1
                    self.waiting.insert(next, at: 0)
                }
                self.lock.unlock()
                
                self.advance()
            } finished: {
                self.lock.lock()
                if let index = self.executing.firstIndex(of: next) {
                    self.executing.remove(at: index)
                }
                self.lock.unlock()
                
                self.advance()
            }
        }
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
