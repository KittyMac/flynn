import Foundation

// Replacement for DispatchGroup (avoids crash on Linux)

fileprivate let lock = NSLock()
fileprivate var flynnGroupDidInit: Bool = false

public extension DispatchGroup {
    func notify(actor: Actor,
                _ block: @escaping () -> (),
                file: StaticString = #file,
                line: UInt64 = #line) {
        notify(queue: .global()) {
            actor.unsafeSend({ _ in
                block()
            }, file, line)
        }
    }
}

fileprivate struct GroupObserver {
    let actor: Actor
    let block: () -> ()
    let file: StaticString
    let line: UInt64
}

public extension Flynn {
    class Group {
        let lock = NSLock()
        var count: Int = 0
        fileprivate var observers: [GroupObserver] = []
        
        public init() { }
        
        public func enter() {
            lock.lock()
            count += 1
            lock.unlock()
        }
        
        public func leave() {
            lock.lock()
            count -= 1
            
            if count <= 0 {
                count = 0
                for observer in observers {
                    observer.actor.unsafeSend({ _ in
                        observer.block()
                    }, observer.file, observer.line)
                }
                observers = []
            }
            
            lock.unlock()
        }
        
        public func wait() {
            while count > 0 {
                Flynn.usleep(50_000)
            }
        }
        
        public func notify(actor: Actor,
                           _ block: @escaping () -> (),
                           file: StaticString = #file,
                           line: UInt64 = #line) {
            lock.lock()
            
            if count == 0 {
                lock.unlock()
                actor.unsafeSend({ _ in
                    block()
                }, file, line)
                return
            }
            
            observers.append(
                GroupObserver(actor: actor,
                              block: block,
                              file: file,
                              line: line)
            )
            lock.unlock()
        }
    }
}
