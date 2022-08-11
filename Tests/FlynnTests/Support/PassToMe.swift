import XCTest

@testable import Flynn

class PassToMe: Actor {

    @inlinable
    internal func _beNone() {
        print("hello world with no arguments")
    }

    @inlinable
    internal func _beString(_ string: String) {
        print(string)
    }

    @inlinable
    internal func _beNSString (_ string: NSString) {
        print(string)
    }

}
