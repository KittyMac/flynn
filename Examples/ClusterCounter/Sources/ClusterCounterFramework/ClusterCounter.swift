import Flynn
import Foundation

public enum ClusterCounter {
    public static func runAsNode(_ address: String, _ port: Int32) {
        print("run as node")

        Flynn.node(address, port, [RemoteCounter.self])

        while true {
            sleep(100)
        }
    }

    public static func runAsRoot(_ address: String, _ port: Int32) {
        print("run as root")

        Flynn.root(address, port)

        let root = RootCounter()

        // wait until the root counts to 1_000_000
        var done = false
        while !done {
            root.beGetTotal(Flynn.any) { (value) in
                print("total: \(value)")
                if value > 1_000_000 {
                    done = true
                }
            }
            sleep(1)
        }

        Flynn.shutdown()
    }
}
