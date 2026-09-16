// flynn:ignore Reentrant ReturnCallbacks

import XCTest
import Flynn

class ActorA: Actor {
    private let b = ActorB()
    private var counter = 0
    
    override init() {
        b.beAdd(x: counter, y: 1, Flynn.any) { result in
            // self.counter = result
        }
        
        let actor = Actor()
        b.beAdd(x: counter, y: 1, actor) { result in
            // self.counter = 0
        }
        
        super.init()
        
        #if os(macOS)
        
        Thread {
            // let _ = self.counter
        }.start()
        Task {
            // let _ = self.counter
        }
        let opetationQueue = OperationQueue()
        opetationQueue.addOperation {
            // let _ = self.counter
        }
        let dispatchQueue = DispatchQueue(label: "some.queue")
        dispatchQueue.async {
            // let _ = self.counter
        }
        dispatchQueue.sync {
            // let _ = self.counter
        }
        DispatchQueue.main.async {
            // let _ = self.counter
        }
        
        let queue = DispatchQueue(label: "some.queue", attributes: .concurrent)

        DispatchQueue.global(qos: .background).async {
            // let _ = self.counter
        }

        queue.asyncAfter(deadline: .now() + 1) {
            // let _ = self.counter
        }

        queue.asyncAndWait {          // iOS 13+, sync-like but with QoS handling
            // let _ = self.counter
        }

        DispatchQueue.concurrentPerform(iterations: 10) { index in
            // let _ = self.counter
        }

        let workItem = DispatchWorkItem {
            // let _ = self.counter
        }
        queue.async(execute: workItem)
        workItem.notify(queue: .main) {
            // let _ = self.counter
        }

        let group = DispatchGroup()
        queue.async(group: group) {
            // let _ = self.counter
        }
        group.notify(queue: .main) {
            // let _ = self.counter
        }
        group.notify(actor: self) {
            let _ = self.counter
        }
        group.notify(actor: Flynn.any) {
            // let _ = self.counter
        }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.setEventHandler {
            // let _ = self.counter
        }
        timer.setCancelHandler {
            // let _ = self.counter
        }
        timer.schedule(deadline: .now(), repeating: 1.0)
        timer.resume()
        
        Thread.detachNewThread {
            // let _ = self.counter
        }

        let blockOp = BlockOperation {
            // let _ = self.counter
        }
        blockOp.addExecutionBlock {
            // let _ = self.counter
        }
        blockOp.completionBlock = {
            // let _ = self.counter
        }
        OperationQueue().addOperation(blockOp)

        OperationQueue.main.addOperation {
            // let _ = self.counter
        }

        let opQueue = OperationQueue()
        opQueue.addBarrierBlock {        // iOS 13+
            // let _ = self.counter
        }
        
        Task.detached {
            // let _ = self.counter
        }

        Task(priority: .background) {
            // let _ = self.counter
        }
        
        let stream = AsyncStream<Int> { continuation in
            // let _ = self.counter
            continuation.finish()
        }
        Task {
            for await _ in stream {
                // let _ = self.counter
            }
        }
        
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            // let _ = self.counter
        }

        RunLoop.main.perform {
            // let _ = self.counter
        }

        NotificationCenter.default.addObserver(
            forName: .NSAppleEventManagerWillProcessFirstEvent,
            object: nil,
            queue: .main
        ) { _ in
            // let _ = self.counter
        }

        let url = URL(fileURLWithPath: "/tmp")
        URLSession.shared.dataTask(with: url) { data, response, error in
            // let _ = self.counter
        }.resume()

        /*
        UIView.animate(withDuration: 0.3) {
            let _ = self.counter
        } completion: { finished in
            let _ = self.counter
        }*/

        let handle = FileHandle.standardInput
        handle.readabilityHandler = { fh in
            // let _ = self.counter
        }

        let process = Process()
        process.terminationHandler = { proc in
            // let _ = self.counter
        }

        #endif
    }
    
    private func runConcurrentTasks() async throws {
        
        #if os(macOS)
        await _Concurrency.MainActor.run {
            // let _ = self.counter
        }

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                // let _ = self.counter
            }
        }

        await withThrowingTaskGroup(of: Int.self) { group in
            group.addTask {
                // let _ = self.counter
                return 0
            }
        }

        await withTaskCancellationHandler {
            // let _ = self.counter
        } onCancel: {
            // let _ = self.counter
        }

        await withCheckedContinuation { continuation in
            // let _ = self.counter
            continuation.resume()
        }
        #endif
        
    }
    
    internal func _beIncrement() {
        // safe: self means the callback will run on myself (this actor)
        b.beAdd(x: counter, y: 1, self) { result in
            self.counter = result
        }
        
        // unsafe: callback will run on the Flynn.any actor and access the internal state
        // of myself (which could be running in a different thread concurrently)
        let actor = Actor()
        b.beAdd(x: counter, y: 1, actor) { result in
            // self.counter = 0
        }
    }
}

class ActorB: Actor {
    internal func _beAdd(x: Int, y: Int) -> Int {
        return x + y
    }
}
