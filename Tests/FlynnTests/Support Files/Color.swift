import XCTest
@testable import Flynn

typealias ColorCallback = ([Float]) -> Void

public class ColorableState {
    fileprivate var color: [Float] = [1, 1, 1, 1]
}

protocol Colorable: Actor {
    var safeColorable: ColorableState { get set }
}

extension Colorable {
    internal func _beColor() {
        print("Colorable.color from \(self)")
    }

    internal func _beAlpha() {
        print("Colorable.alpha from \(self)")
    }

    internal func _beGetColor(_ callback: @escaping ([Float]) -> Void) {
        callback(self.safeColorable.color)
    }

    internal func _beGetColor2(_ callback: @escaping ColorCallback) {
        callback(self.safeColorable.color)
    }

    internal func _beSetColor(_ color: [Float]) {
        self.safeColorable.color = color
    }
}

public final class Color: Actor, Colorable, Viewable {
    public var safeColorable = ColorableState()
}
