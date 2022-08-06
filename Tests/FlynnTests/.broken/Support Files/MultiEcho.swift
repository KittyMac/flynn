import XCTest
@testable import Flynn

class MultiEchoA: RemoteActor {
    internal func _beEcho(_ string: String) -> String {
        return "[A] " + string
    }
}

class MultiEchoB: RemoteActor {
    internal func _beEcho(_ string: String) -> String {
        return "[B] " + string
    }
}

class MultiEchoC: RemoteActor {
    internal func _beEcho(_ string: String) -> String {
        return "[C] " + string
    }
}
