import XCTest
import Flynn

protocol Viewable: Actor {

    @discardableResult
    func beRender(_ file: StaticString, _ line: UInt64) -> Self
}

extension Viewable {

    @inlinable internal func _beRender() {
        print("Viewable.render")
    }
}
