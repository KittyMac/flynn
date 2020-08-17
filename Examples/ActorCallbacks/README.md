## Actor Callbacks

As we know, actors are concurrency safe classes whose internals cannot be directly accessed from outside of the class. So if an actor needs a value from a different actor, how can it retrieve values concurrently using behaviors?

### Secnario 1

In this scenario we want to create a generic API callback from one actor to some other actor.  In short, we send the callback actor to a behavior, and that actor needs to adhere to a protocol which defines the behavior we expect to callback to. This scenario works well for actor collaboration which follows specific, modular, well defined paths.

```swift
protocol ConcurrentDatastoreRetrievable {
    @discardableResult
    func beRetrieveValue(_ key: String, _ value: Any?) -> Self
}

class ConcurrentDatastore: Actor {
    private var storage: [String: Any?] = [:]

    private func _beGet(_ key: String, _ sender: ConcurrentDatastoreRetrievable) {
        if let value = storage[key] {
            sender.beRetrieveValue(key, value)
        }
    }

    private func _beSet(_ key: String, _ value: Any?) {
        storage[key] = value
    }

}
```

```swift
class Scenario1: Actor, ConcurrentDatastoreRetrievable {
    private let monsters: ConcurrentDatastore

    init(_ monsters: ConcurrentDatastore) {
        self.monsters = monsters
        super.init()
    }

    private func _beRetrieveValue(_ key: String, _ value: Any?) {
        if let value = value {
            print("\(value)")
        }
    }

    private func _bePrint(_ name: String) {
        // retrieves value from storage using protocol and a callback actor
        // who adheres to a protocol defining the behavior to callback on
        monsters.beGet(name, self)
    }
}
```

### Secnario 2

In this scenario, we want to be able use the retrieved information without the rigid structure. To do this we want to pass a closure to ConcurrentDatastore, the contents of which will utilized the retrieved information. The closure in this case becomes the behavior we want to be called. However, the onus is on ConcurrentDatastore to call it correctly. ConcurrentDatastore cannot just execute the closure, as it will then run the contents of the closure on ConcurrentDatastore actor's "thread", potentially while the Scenario actor's "thread" is also running.  All ConcurrentDatastore needs to do is wrap the call to the closure with unsafeSend {}, which will ensure the closure runs on the Scenario actor, just as if the closure was a fully-defined behavior.

```swift
class ConcurrentDatastore: Actor {
    private var storage: [String: Any?] = [:]

    private func _beGet(_ key: String, _ sender: Actor, _ block: @escaping (Any?) -> Void) {
        if let value = storage[key] {
            // This unsafeSend is critical. If we just call the closure directly, then
            // it will execute on the ConcurrentDatastore Actor's "thread" and it could
            // lead to the sending actor running on two threads at the same time. By
            // calling unsafeSend, the closure executes as if it were a behavior, so the
            // closure will execute safely on the sending actor.
            sender.unsafeSend {
                block(value)
            }
        }
    }

    private func _beSet(_ key: String, _ value: Any?) {
        storage[key] = value
    }

}
```

```swift
class Scenario2: Actor {
    private let monsters: ConcurrentDatastore

    init(_ monsters: ConcurrentDatastore) {
        self.monsters = monsters
        super.init()
    }

    private func _bePrint(_ name: String) {
        // retrieves value from storage using protocol and closure. It is
        // important that ConcurrentDatastore is implemented to correctly
        // wrap the closure in unsafeSend {} to ensure it executes on
        // Scenario2 in a concurrency safe manner
        monsters.beGet(name, self) { value in
            if let value = value {
                print("\(value)")
            }
        }
    }
}
```

