import XCTest

@testable import Flynn

class StringBuilder: Actor, Timerable {
    private var string: String = ""

    internal func _beTimerFired(_ timer: Flynn.Timer, _ args: TimerArgs) {
        let value: String = args[x:0]
        string.append(value)
    }

    internal func _beAppend(_ value: String) {
        string.append(value)
    }

    internal func _beSpace() {
        string.append(" ")
    }

    internal func _beResult(_ callback: @escaping ((String) -> Void)) {
        callback(string)
    }
}
