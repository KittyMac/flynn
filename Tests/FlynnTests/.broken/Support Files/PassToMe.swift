import XCTest

@testable import Flynn

class PassToMe: Actor {

    internal func _beNone() {
        print("hello world with no arguments")
    }

    internal func _beString(_ string: String) {
        print(string)
    }

    internal func _beNSString (_ string: NSString) {
        print(string)
    }

}
