import Foundation

// swiftlint:disable all

public enum Pamphlet {
    public static func get(string member: String) -> String? {
        switch member {

        default: break
        }
        return nil
    }
    public static func get(gzip member: String) -> Data? {
        #if DEBUG
            return nil
        #else
            switch member {

            default: break
            }
            return nil
        #endif
    }
    public static func get(data member: String) -> Data? {
        switch member {

        default: break
        }
        return nil
    }
}
