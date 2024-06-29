import Foundation

// Like OperationQueue, but allows the following:
// - ability to force cancel infinite looping operations
// - ability to provide a timeout for operations (and cancelling when exceeding said timeout)

private class TimedOperation {
    let block: () -> ()
    let timeout: TimeInterval?
    
    var queuedDate: Date = Date()
    var executionDate: Date? = nil
    var localExecuting = false
    var localFinished = false
    var thread: Thread? = nil
    
    init(timeout: TimeInterval?,
         block: @escaping () -> Void) {
        self.timeout = timeout
        self.block = block
    }
    
    func start() {
        thread = Thread {
            Flynn.threadSetName("TimedOperation")
            
            self.localExecuting = true
            self.executionDate = Date()
            self.block()
            self.localExecuting = false
            self.localFinished = true
        }
        thread?.start()
    }
    
    func isFinished() -> Bool {
        if localFinished {
            return true
        }
        
        if let executionDate = executionDate,
           let timeout = timeout,
           abs(executionDate.timeIntervalSinceNow) > timeout {
            thread?.cancel()
            return true
        }
        return false
    }
}

private struct WeakTimedOperationQueue {
    weak var timedOperationQueue: TimedOperationQueue?
}

public class TimedOperationQueue {
    
    public var maxConcurrentOperationCount: Int = 1
    
    private var waiting: [TimedOperation] = []
    private var executing: [TimedOperation] = []
    
    private let lock = NSLock()
    
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
                    weakTimedOperationQueues = weakTimedOperationQueues.filter {
                        $0.timedOperationQueue?.advance()
                        return $0.timedOperationQueue != nil
                    }
                    
                    Flynn.usleep(50_000)
                }
            }.start()
        }
        staticLock.unlock()
    }
    
    // TODO: TimedOperation should use a single pool of threads maintained by someone
    // (instead of creating a new thread each run)
    public init() {
        TimedOperationQueue.register(self)
    }
    
    public func addOperation(timeout: TimeInterval, _ block: @escaping () -> ()) {
        lock.lock()
        waiting.append(TimedOperation(timeout: timeout, block: block))
        lock.unlock()
    }
    
    public func addOperation(_ block: @escaping () -> ()) {
        lock.lock()
        waiting.append(TimedOperation(timeout: nil, block: block))
        lock.unlock()
    }
    
    fileprivate func advance() {
        lock.lock()
        
        for idx in stride(from: executing.count-1, through: 0, by: -1) {
            let operation = executing[idx]
            if operation.isFinished() {
                executing.remove(at: idx)
            }
        }
        while executing.count < maxConcurrentOperationCount && waiting.count > 0 {
            let next = waiting.removeFirst()
            executing.append(next)
            next.start()
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
