import Foundation
import Pony

public enum CoreAffinity: Int32 {
    case preferEfficiency = 0
    case preferPerformance = 1
    case onlyEfficiency = 2
    case onlyPerformance = 3
    case none = 99
}

open class Flynn {

    // MARK: - User Configurable Settings

#if os(iOS)
    public static var defaultActorAffinity: CoreAffinity = .preferEfficiency
#else
    public static var defaultActorAffinity: CoreAffinity = .none
#endif

    private static var timerLoop: TimerLoop?
    private static var running = AtomicContidion()

    private static var timeStart: TimeInterval = 0
    private static var registeredActorsCheckRunning = false

    public static let any = Actor()

    public class func startup() {
        running.checkInactive {
            timeStart = ProcessInfo.processInfo.systemUptime

            timerLoop = TimerLoop()

            pony_startup()
        }
    }

    public class func shutdown() {
        running.checkActive {

            pony_shutdown()

            timerLoop?.join()
            timerLoop = nil

            // wait until the registered actors thread ends
            clearRegisteredTimers()
        }
    }

    public static var cores: Int {
        return Int(pony_core_count())
    }

    public static var eCores: Int {
        return Int(pony_e_core_count())
    }

    public static var pCores: Int {
        return Int(pony_p_core_count())
    }

    public static var remoteNodes: Int {
        return Int(pony_remote_slaves_count())
    }

    public static var remoteCores: Int {
        return Int(pony_remote_core_count())
    }

    internal static func wakeTimerLoop() {
        timerLoop?.wake()
    }
}
