import XCTest
import Flynn

public class ImageableState {
    fileprivate var path: String = ""
}

protocol Imageable: Actor {
    var safeImageable: ImageableState { get set }
}

extension Imageable {
    @inlinable 
    internal func _bePath(_ path: String) {
        safeImageable.path = path
    }
}

public final class Image: Actor, Colorable, Imageable, Viewable {
    public var safeColorable = ColorableState()
    public var safeImageable = ImageableState()
}
