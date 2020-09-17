import Flynn
import Foundation

public enum ClusterCounter {
    public static func runAsSlave(_ address: String, _ port: Int32) {
        print("run as slave")

        Flynn.slave(address, port, [RemoteCounter.self])

        while true {
            sleep(100)
        }
    }

    public static func runAsMaster(_ address: String, _ port: Int32) {
        print("run as master")

        Flynn.master(address, port)

        let master = MasterCounter()

        // wait until the master counts to 1_000_000
        var done = false
        while !done {
            master.beGetTotal(Flynn.any) { (value) in
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
