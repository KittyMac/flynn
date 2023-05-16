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

fileprivate let pool = Array<Actor>.init(count: 32, create: { return Actor() })

// Simple parallel processing for common collections
// Process each item concurrently and
// wait for all actors to finish
fileprivate func _sync<T: Collection>(_ collection: T,
                                      _ block: @escaping (T.Element) -> ()) {
    let group = DispatchGroup()
    var actorIdx = 0
    for item in collection {
        actorIdx = (actorIdx + 1) % pool.count
        group.enter()
        pool[actorIdx].unsafeSend { _ in
            block(item)
            group.leave()
        }
    }
    group.wait()
}

// Process each item concurrently without waiting, calling
// the returnCallback on the provided actor when finished
fileprivate func _async<T: Collection>(_ collection: T,
                                       _ block: @escaping (T.Element) -> (),
                                       _ sender: Actor,
                                       _ returnComplete: @escaping () -> ()) {
    var actorIdx = 0
    var waiting = collection.count
    let lock = NSLock()
    for item in collection {
        actorIdx = (actorIdx + 1) % pool.count
        pool[actorIdx].unsafeSend { _ in
            block(item)
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
    func async(_ block: @escaping (Self.Element) -> (),
               _ sender: Actor,
               _ returnComplete: @escaping () -> ()) {
        _async(self, block, sender, returnComplete)
    }
    func sync(_ block: @escaping (Self.Element) -> ()) {
        _sync(self, block)
    }
}
