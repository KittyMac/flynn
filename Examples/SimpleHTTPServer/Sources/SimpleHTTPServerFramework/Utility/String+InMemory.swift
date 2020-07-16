import Flynn
import Foundation
import Socket

@propertyWrapper
public struct InMemory {
    var value: String?
    let startPtr: UnsafeMutablePointer<CChar>?
    let endPtr: UnsafeMutablePointer<CChar>?

    public init(initialValue value: String?,
                _ startPtr: UnsafeMutablePointer<CChar>,
                _ endPtr: UnsafeMutablePointer<CChar>) {
        self.value = value
        self.startPtr = startPtr
        self.endPtr = endPtr
    }

    public init() {
        value = nil
        startPtr = nil
        endPtr = nil
    }

    @inline(__always)
    func isEmpty() -> Bool {
        return value == nil
    }

    @inline(__always)
    public var wrappedValue: String? {
        get {
            if value == nil && (startPtr == nil || endPtr == nil) {
                return nil
            }
            if let value = value {
                return value
            }
            if  let startPtr = startPtr,
                let endPtr = endPtr {
                return String(bytesNoCopy: startPtr,
                              length: endPtr - startPtr,
                              encoding: .utf8,
                              freeWhenDone: false)
            }
            return nil
        }
        set { value = newValue }
    }

    public var projectedValue: Self {
      get { self }
      set { self = newValue }
    }

}
