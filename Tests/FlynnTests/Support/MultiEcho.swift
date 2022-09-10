import XCTest
import Flynn

class MultiEchoA: RemoteActor {
    @inlinable
    internal func _beEcho(_ string: String) -> String {
        return "[A] " + string
    }
}

class MultiEchoB: RemoteActor {
    @inlinable
    internal func _beEcho(_ string: String) -> String {
        return "[B] " + string
    }
}

class MultiEchoC: RemoteActor {
    @inlinable
    internal func _beEcho(_ string: String) -> String {
        return "[C] " + string
    }
}
