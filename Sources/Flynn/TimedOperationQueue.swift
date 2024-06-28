import Foundation

// Like OperationQueue, but allows the following:
// - ability to force cancel infinite looping operations
// - ability to provide a timeout for operations (and cancelling when exceeding said timeout)

private class TimedOperation {
    let block: () -> ()
    let timeout: TimeInterval
    
    var queuedDate: Date = Date()
    var executionDate: Date? = nil
    var localExecuting = false
    var localFinished = false
    var thread: Thread? = nil
    
    init(timeout: TimeInterval,
         block: @escaping () -> Void) {
        self.timeout = timeout
        self.block = block
    }
    
    func start() {
        thread = Thread {
            Thread.current.name = "TimedOperation"
            
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
           abs(executionDate.timeIntervalSinceNow) > timeout {
            thread?.cancel()
            return true
        }
        return false
    }
}

public class TimedOperationQueue {
    
    public var maxConcurrentOperationCount: Int = 1
    
    private var waiting: [TimedOperation] = []
    private var executing: [TimedOperation] = []
    
    public func addOperation(timeout: TimeInterval, _ block: @escaping () -> ()) {
        waiting.append(TimedOperation(timeout: timeout, block: block))
    }
    
    public func run() {
        while waiting.count + executing.count > 0 {
            Flynn.usleep(500)
            
            for idx in stride(from: executing.count-1, through: 0, by: -1) {
                let operation = executing[idx]
                if operation.isFinished() {
                    executing.remove(at: idx)
                }
            }
            
            if executing.count < maxConcurrentOperationCount,
               waiting.count > 0 {
                let next = waiting.removeFirst()
                executing.append(next)
                next.start()
            }
        }
    }
}
