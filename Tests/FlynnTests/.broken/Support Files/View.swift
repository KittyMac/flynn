import XCTest
@testable import Flynn

protocol Viewable: Actor {

    @discardableResult
    func beRender() -> Self
}

extension Viewable {

    internal func _beRender() {
        print("Viewable.render")
    }
}
