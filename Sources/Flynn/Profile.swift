import Foundation

func printTimeElapsedWhenRunningCode(title: String, operation:() -> Void) {
    let startTime = ProcessInfo.processInfo.systemUptime
    operation()
    let timeElapsed = ProcessInfo.processInfo.systemUptime - startTime
    print("Time elapsed for \(title): \(Int(timeElapsed * 1000)) ms")
}

func timeElapsedInSecondsWhenRunningCode(operation: () -> Void) -> Double {
    let startTime = ProcessInfo.processInfo.systemUptime
    operation()
    let timeElapsed = ProcessInfo.processInfo.systemUptime - startTime
    return Double(timeElapsed)
}

class ProfileStats {
    var numSchedules: Int64 = 0
    var timeSchedules: Double = 0

    func recordSchedule(operation: () -> Void) {
        let startTime = ProcessInfo.processInfo.systemUptime
        operation()
        let timeElapsed = ProcessInfo.processInfo.systemUptime - startTime

        numSchedules += 1
        timeSchedules += timeElapsed
    }

    func printStats() {
        print("numSchedules: \(numSchedules)")
        print("timeSchedules: \(timeSchedules)")
    }
}
