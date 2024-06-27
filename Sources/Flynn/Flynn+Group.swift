import Foundation

// Replacement for DispatchGroup (avoids crash on Linux)

fileprivate let lock = NSLock()
fileprivate var flynnGroupDidInit: Bool = false

public extension DispatchGroup {
    func notify(actor: Actor,
                _ block: @escaping () -> ()) {
        notify(queue: .global()) {
            actor.unsafeSend { _ in
                block()
            }
        }
    }
}

fileprivate struct GroupObserver {
    let actor: Actor
    let block: () -> ()
}

public extension Flynn {
    class Group {
        let lock = NSLock()
        var count: Int = 0
        fileprivate var observers: [GroupObserver] = []
        
        func enter() {
            lock.lock()
            count += 1
            lock.unlock()
        }
        
        func leave() {
            lock.lock()
            count -= 1
            
            if count <= 0 {
                count = 0
                for observer in observers {
                    observer.actor.unsafeSend { _ in
                        observer.block()
                    }
                }
                observers = []
            }
            
            lock.unlock()
        }
        
        func wait() {
            while count > 0 {
                Flynn.usleep(50_000)
            }
        }
        
        func notify(actor: Actor,
                    _ block: @escaping () -> ()) {
            lock.lock()
            
            if count == 0 {
                actor.unsafeSend { _ in
                    block()
                }
                return
            }
            
            observers.append(
                GroupObserver(actor: actor,
                              block: block)
            )
            lock.unlock()
        }
    }
}
