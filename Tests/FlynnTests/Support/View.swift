import XCTest
@testable import Flynn

protocol Viewable: Actor {

    @discardableResult
    func beRender() -> Self
}

extension Viewable {

    @inlinable internal func _beRender() {
        print("Viewable.render")
    }
}
