import Foundation

class AtomicContidion {
    private var _value: Bool = false
    private var lock = NSLock()

    public var isActive: Bool {
        return _value
    }

    func checkInactive(_ block: () -> Void) {
        if _value == false {
            lock.lock()
            if _value == false {
                _value = true
                block()
            }
            lock.unlock()
        }
    }

    func checkActive(_ block: () -> Void) {
        if _value == true {
            lock.lock()
            if _value == true {
                block()
                _value = false
            }
            lock.unlock()
        }
    }
}

class AtomicCount {
    private var _value: Int32 = 0
    private var lock = NSLock()

    func inc() {
        lock.lock()
        _value += 1
        lock.unlock()
    }

    func dec() {
        lock.lock()
        _value -= 1
        lock.unlock()
    }

    var value: Int32 {
        return _value
    }

}
