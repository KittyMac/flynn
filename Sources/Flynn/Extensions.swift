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
    var actorIdx = 0
    var waiting = collection.count
    let lock = NSLock()
    let poolCount = min(maxActors, count > 0 && count < Flynn.cores ? count : Flynn.cores)
    for item in collection {
        actorIdx = (actorIdx + 1) % poolCount
        pool[actorIdx].unsafeSend { _ in
            block(item) { synchronized in
                lock.lock()
                synchronized()
                lock.unlock()
            }
            lock.lock()
            waiting -= 1
            if waiting <= 0 {
                sender.unsafeSend { _ in
                    returnComplete()
                }
            }
            lock.unlock()
        }
    }
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
}
