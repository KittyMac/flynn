import XCTest

import Flynn

class StringBuilder: Actor, Timerable {
    private var string: String = ""

    @inlinable internal func _beTimerFired(_ timer: Flynn.Timer, _ args: TimerArgs) {
        let value: String = args[x:0]
        string.append(value)
    }

    @inlinable internal func _beAppend(_ value: String) {
        string.append(value)
    }

    @inlinable internal func _beSpace() {
        string.append(" ")
    }

    @inlinable internal func _beResult(_ callback: @escaping ((String) -> Void)) {
        callback(string)
    }
}
