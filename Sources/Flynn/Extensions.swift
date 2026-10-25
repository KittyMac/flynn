import Foundation

public typealias NewObject = (() -> AnyObject)

extension Array {
    public init(count: Int, create: NewObject) {
        self.init()
        for _ in 0..<count {
            self.append(create() as! Element)
        }
    }
}

fileprivate class CollectionActor: Actor {
    override init() {
        super.init()
        unsafeMessageBatchSize = 1
        unsafePriority = -1
    }
}

fileprivate let maxActors = 128

public typealias emptyBlock = () -> ()
public typealias synchronizedBlock = (emptyBlock) -> ()

fileprivate let pool = Array<Actor>.init(count: maxActors, create: { return CollectionActor() })

/// Hands out a collection's elements one at a time to whichever worker asks next.
/// Workers pull rather than having items pushed to them up front, so a batch of millions
/// of items needs no per-item queue entries or closures, and a worker that draws slow
/// items does not leave the others idle at the end.
fileprivate final class CollectionCursor<T: Collection> {
    let collection: T
    let block: (T.Element, @escaping synchronizedBlock) -> ()
    let synchronized: synchronizedBlock
    
    private let lock = NSLock()
    private var nextIndex: T.Index
    
    init(_ collection: T,
         _ block: @escaping (T.Element, @escaping synchronizedBlock) -> ()) {
        self.collection = collection
        self.block = block
        self.nextIndex = collection.startIndex
        
        let synchronizedLock = NSLock()
        self.synchronized = { synchronized in
            synchronizedLock.lock()
            synchronized()
            synchronizedLock.unlock()
        }
    }
    
    func next() -> T.Element? {
        lock.lock()
        defer { lock.unlock() }
        guard nextIndex != collection.endIndex else { return nil }
        let item = collection[nextIndex]
        collection.formIndex(after: &nextIndex)
        return item
    }
}

fileprivate func workerCount(_ count: Int) -> Int {
    return min(maxActors, count > 0 && count < Flynn.cores ? count : Flynn.cores)
}

/// One worker on a pool actor: process one item, then re-send to itself for the next.
/// Re-sending (instead of looping) yields the actor's scheduler thread between items,
/// as the previous one-message-per-item version did, while keeping at most one message
/// per worker queued.
fileprivate func pump<T: Collection>(_ actor: Actor,
                                     _ cursor: CollectionCursor<T>,
                                     _ group: DispatchGroup) {
    actor.unsafeSend { _ in
        guard let item = cursor.next() else {
            group.leave()
            return
        }
        cursor.block(item, cursor.synchronized)
        pump(actor, cursor, group)
    }
}

fileprivate func startPumps<T: Collection>(count: Int,
                                           _ collection: T,
                                           _ block: @escaping (T.Element, @escaping synchronizedBlock) -> ()) -> DispatchGroup {
    let group = DispatchGroup()
    let cursor = CollectionCursor(collection, block)
    let workers = min(workerCount(count), collection.count)
    for idx in 0..<workers {
        group.enter()
        pump(pool[idx], cursor, group)
    }
    return group
}

// Simple parallel processing for common collections
// Process each item concurrently and
// wait for all actors to finish
fileprivate func _sync<T: Collection>(count: Int,
                                      _ collection: T,
                                      _ block: @escaping (T.Element, @escaping synchronizedBlock) -> ()) {
    startPumps(count: count, collection, block).wait()
}

// Process each item concurrently without waiting, calling
// the returnCallback on the provided actor when finished
fileprivate func _async<T: Collection>(count: Int,
                                       _ collection: T,
                                       _ block: @escaping (T.Element, @escaping synchronizedBlock) -> (),
                                       _ sender: Actor,
                                       _ returnComplete: @escaping () -> ()) {
    startPumps(count: count, collection, block).notify(actor: sender, returnComplete)
}

/// Runs a collection on dedicated threads ("out-of-band" as far as the Flynn scheduler
/// is concerned), each thread pulling items until none are left.
///
/// With a positive timeout, an item running longer than the timeout is abandoned: its
/// thread is left to finish on its own, it no longer counts toward the concurrency limit,
/// a replacement thread takes over the remaining items, and completion does not wait for
/// it. A timeout of zero or less means no timeout.
fileprivate final class OOBRun<T: Collection> {
    private final class Worker {
        var itemStart: Date?
        var abandoned = false
    }
    
    private let cursor: CollectionCursor<T>
    private let timeout: TimeInterval
    private let condition = NSCondition()
    
    // Guarded by condition
    private var workers: [Worker] = []
    private var activeWorkers: Int { return workers.count }
    private var itemsRemaining = true
    
    init(timeout: TimeInterval,
         _ collection: T,
         _ block: @escaping (T.Element, @escaping synchronizedBlock) -> ()) {
        self.timeout = timeout
        self.cursor = CollectionCursor(collection, block)
    }
    
    private func startWorker() {
        // caller holds condition
        let worker = Worker()
        workers.append(worker)
        Thread {
            Flynn.threadSetName("Flynn OOB")
            self.work(worker)
        }.start()
    }
    
    private func work(_ worker: Worker) {
        let tracksTime = timeout > 0
        while true {
            condition.lock()
            worker.itemStart = nil
            guard worker.abandoned == false,
                  let item = cursor.next() else {
                if worker.abandoned == false {
                    itemsRemaining = false
                    workers.removeAll { $0 === worker }
                    condition.broadcast()
                }
                condition.unlock()
                return
            }
            if tracksTime {
                worker.itemStart = Date()
            }
            condition.unlock()
            
            cursor.block(item, cursor.synchronized)
        }
    }
    
    /// Starts the workers and blocks until every item has finished or been abandoned.
    func run(count: Int) {
        let workers = min(workerCount(count), cursor.collection.count)
        guard workers > 0 else { return }
        
        condition.lock()
        for _ in 0..<workers {
            startWorker()
        }
        
        while activeWorkers > 0 {
            guard timeout > 0 else {
                condition.wait()
                continue
            }
            
            _ = condition.wait(until: Date(timeIntervalSinceNow: min(timeout, 0.5)))
            
            let now = Date()
            var abandonedCount = 0
            for worker in self.workers {
                if let itemStart = worker.itemStart,
                   now.timeIntervalSince(itemStart) > timeout {
                    worker.abandoned = true
                    abandonedCount += 1
                }
            }
            if abandonedCount > 0 {
                self.workers.removeAll { $0.abandoned }
                if itemsRemaining {
                    for _ in 0..<abandonedCount {
                        startWorker()
                    }
                }
            }
        }
        condition.unlock()
    }
}

// The same as the two methods above, but will use dedicated threads to
// perform the work. This means that the work will be performed "out-of-band"
// as far as the flynn scheduler is concerned, which can be useful especially
// for sync() operations or those which require file i/o
fileprivate func _syncOOB<T: Collection>(count: Int,
                                         timeout: TimeInterval,
                                         _ collection: T,
                                         _ block: @escaping (T.Element, @escaping synchronizedBlock) -> ()) {
    OOBRun(timeout: timeout, collection, block).run(count: count)
}

fileprivate func _asyncOOB<T: Collection>(count: Int,
                                          timeout: TimeInterval,
                                          _ collection: T,
                                          _ block: @escaping (T.Element, @escaping synchronizedBlock) -> (),
                                          _ sender: Actor,
                                          _ returnComplete: @escaping () -> ()) {
    let run = OOBRun(timeout: timeout, collection, block)
    Thread {
        Flynn.threadSetName("Flynn OOB")
        run.run(count: count)
        sender.unsafeSend { _ in
            returnComplete()
        }
    }.start()
}

public extension Collection {
    func async(count: Int = 0,
               _ sender: Actor,
               each: @escaping (Self.Element, @escaping synchronizedBlock) -> (),
               done: @escaping () -> ()) {
        _async(count: count, self, each, sender, done)
    }
    func sync(count: Int = 0, _ block: @escaping (Self.Element, @escaping synchronizedBlock) -> ()) {
        _sync(count: count, self, block)
    }
    
    func asyncOOB(count: Int = 0,
                  timeout: TimeInterval,
                  _ sender: Actor,
                  each: @escaping (Self.Element, @escaping synchronizedBlock) -> (),
                  done: @escaping () -> ()) {
        _asyncOOB(count: count, timeout: timeout, self, each, sender, done)
    }
    func syncOOB(count: Int = 0, timeout: TimeInterval, _ block: @escaping (Self.Element, @escaping synchronizedBlock) -> ()) {
        _syncOOB(count: count, timeout: timeout, self, block)
    }
}
