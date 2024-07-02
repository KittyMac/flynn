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

// Simple parallel processing for common collections
// Process each item concurrently and
// wait for all actors to finish
fileprivate func _sync<T: Collection>(count: Int,
                                      _ collection: T,
                                      _ block: @escaping (T.Element, @escaping synchronizedBlock) -> ()) {
    let group = DispatchGroup()
    var actorIdx = 0
    let lock = NSLock()
    let poolCount = min(maxActors, count > 0 && count < Flynn.cores ? count : Flynn.cores)
    for item in collection {
        actorIdx = (actorIdx + 1) % poolCount
        group.enter()
        pool[actorIdx].unsafeSend { _ in
            block(item) { synchronized in
                lock.lock()
                synchronized()
                lock.unlock()
            }
            group.leave()
        }
    }
    group.wait()
}

// Process each item concurrently without waiting, calling
// the returnCallback on the provided actor when finished
fileprivate func _async<T: Collection>(count: Int,
                                       _ collection: T,
                                       _ block: @escaping (T.Element, @escaping synchronizedBlock) -> (),
                                       _ sender: Actor,
                                       _ returnComplete: @escaping () -> ()) {
    let group = DispatchGroup()
    var actorIdx = 0
    let lock = NSLock()
    let poolCount = min(maxActors, count > 0 && count < Flynn.cores ? count : Flynn.cores)
    for item in collection {
        actorIdx = (actorIdx + 1) % poolCount
        group.enter()
        pool[actorIdx].unsafeSend { _ in
            block(item) { synchronized in
                lock.lock()
                synchronized()
                lock.unlock()
            }
            group.leave()
        }
    }
    group.notify(actor: sender, returnComplete)
}

// The same as the two methods above, but will use an OperationQueue to
// perform the work. This means that the work will be befored "out-of-band"
// as far as the flynn scheduler is concerned, which can be useful especially
// for sync() operations or those which require file i/o
fileprivate func _syncOOB<T: Collection>(count: Int,
                                         timeout: TimeInterval,
                                         _ collection: T,
                                         _ block: @escaping (T.Element, @escaping synchronizedBlock) -> ()) {
    let queue = TimedOperationQueue()
    queue.maxConcurrentOperationCount = min(maxActors, count > 0 && count < Flynn.cores ? count : Flynn.cores)
    
    let lock = NSLock()
    for item in collection {
        queue.addOperation(timeout: timeout) {
            block(item) { synchronized in
                lock.lock()
                synchronized()
                lock.unlock()
            }
        }
    }
    
    queue.run()
}

fileprivate func _asyncOOB<T: Collection>(count: Int,
                                          _ collection: T,
                                          _ block: @escaping (T.Element, @escaping synchronizedBlock) -> (),
                                          _ sender: Actor,
                                          _ returnComplete: @escaping () -> ()) {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = min(maxActors, count > 0 && count < Flynn.cores ? count : Flynn.cores)
    
    let group = DispatchGroup()
    let lock = NSLock()
    for item in collection {
        group.enter()
        queue.addOperation {
            block(item) { synchronized in
                lock.lock()
                synchronized()
                lock.unlock()
            }
            group.leave()
        }
    }
    group.notify(actor: sender, returnComplete)
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
        _asyncOOB(count: count, self, each, sender, done)
    }
    func syncOOB(count: Int = 0, timeout: TimeInterval, _ block: @escaping (Self.Element, @escaping synchronizedBlock) -> ()) {
        _syncOOB(count: count, timeout: timeout, self, block)
    }
}
