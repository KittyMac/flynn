import XCTest
@testable import Flynn

class Nate: Actor {

    @inlinable internal func _beToLower(_ string: String) -> String {
        return string.lowercased()
    }

}
