import XCTest
@testable import Flynn

class Echo: RemoteActor {
    private let echoUUID = UUID().uuidString
    private var count: Int = 999

    override func safeInit() {
        count = 0
    }

    internal func _bePrintThreadName() -> Int {
        if let name = Thread.current.name {
            sleep(1)
            print("Echo running on \(name)")
        }
        return 0
    }

    internal func _bePrint(_ string: String) {
        print("on node: '\(string)'")
    }

    internal func _beToLower(_ string: String) -> String {
        count += 1
        return "\(string) [\(count)]".lowercased()
    }

    internal func _beTestDelayedReturn(_ string: String, _ returnCallback: @escaping (String) -> Void) {
        Flynn.Timer(timeInterval: Double.random(in: 0..<3), repeats: false, safeActor) { (_) in
            returnCallback(string.uppercased())
        }
    }

    internal func _beTestFailReturn(_ returnCallback: @escaping (String) -> Void) {
        // This behavior purposefully does not call its returnCallback so the
        // unit test can check error callbacks
        close(nodeSocketFD)
    }
}
