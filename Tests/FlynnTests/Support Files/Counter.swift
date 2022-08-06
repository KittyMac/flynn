import XCTest

@testable import Flynn

class Counter: Actor, Timerable {
    private var counter: Int = 0

    private func apply(_ value: Int) {
        counter += value
    }

    internal func _beTimerFired(_ timer: Flynn.Timer, _ args: TimerArgs) {
        counter += args[x:0]
    }

    internal func _beHello(_ string: String) {
        print("hello world from " + string)
    }

    internal func _beInc(_ value: Int) {
        self.apply(value)
    }
    internal func _beDec(_ value: Int) {
        self.apply(-value)
    }
    internal func _beEquals(_ callback: @escaping ((Int) -> Void)) {
        callback(self.counter)
    }

    internal func _beGetValue() -> Int {
        return counter
    }
}
