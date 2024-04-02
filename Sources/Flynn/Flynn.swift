import Foundation
import Pony

public enum CoreAffinity: Int32 {
    case preferEfficiency = 0
    case preferPerformance = 1
    case onlyEfficiency = 2
    case onlyPerformance = 3
    case none = 99
}

// MainActor is a special actor who will use GCD to dispatch
// messages to be executed on the main thread. You can have
// your own MainActor simply by subclasses MainActor. You can
// also just use Flynn.main
public class MainActor: Actor {
    @discardableResult
    @inlinable
    public override func unsafeSend(_ block: @escaping PonyBlock) -> Self {
        guard let _ = safePonyActorPtr else {
            print("Warning: unsafeSend called on a cancelled actor")
            return self
        }
        DispatchQueue.main.async {
            block(0)
        }
        return self
    }
    
    @discardableResult
    @inlinable
    public override func unsafeDo(_ block: @escaping PonyBlock,
                                  _ file: StaticString = #file,
                                  _ line: UInt64 = #line,
                                  _ column: UInt64 = #column) -> Self {
        guard let _ = safePonyActorPtr else {
            print("Warning: unsafeSend called on a cancelled actor")
            return self
        }
        fatalError("then/do is not supported on MainActor")
    }
}

public extension DispatchGroup {
    func notify(actor: Actor,
                _ block: @escaping () -> ()) {
        notify(queue: .global()) {
            actor.unsafeSend { _ in
                block()
            }
        }
    }
}

open class Flynn {

    // MARK: - User Configurable Settings

#if os(iOS)
    public static var defaultActorAffinity: CoreAffinity = .preferEfficiency
#else
    public static var defaultActorAffinity: CoreAffinity = .none
#endif

    private static var dockedQueue = Queue<Actor>(size: 1024,
                                                  manyProducers: true,
                                                  manyConsumers: true)
    
    private static var timerLoop: TimerLoop?
    private static var running = AtomicContidion()

    private static var timeStart: TimeInterval = 0
    private static var registeredActorsCheckRunning = false

    public static let any = Actor()
    public static let main = MainActor()
    
    public static let ignore: () -> () = { }
    public static let warning: () -> () = {
        print("warning: remote call error'd out")
    }
    public static let fatal: () -> () = {
        fatalError("Flynn.fatal called")
    }
    
    static var remotes = RemoteActorManager()

    public class func startup(schedulerCount: Int = 0) {
        running.checkInactive {
            timeStart = ProcessInfo.processInfo.systemUptime

            timerLoop = TimerLoop()
            
            pony_startup(Int32(schedulerCount))
        }
    }

    public class func shutdown(waitForRemotes: Bool = false) {
        running.checkActive {
            pony_shutdown(waitForRemotes)
            
            remotes.unsafeReset()
            remotes = RemoteActorManager()
            
            timerLoop?.join()
            timerLoop = nil

            // wait until the registered actors thread ends
            clearRegisteredTimers()
        }
    }
    
    public class func dock(_ actor: Actor) {
        dockedQueue.enqueue(actor)
    }
    
    public class func undock(_ actor: Actor) {
        dockedQueue.dequeueAny { $0.unsafeUUID == actor.unsafeUUID }
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
    
    public static var remoteEnabled: Bool {
        return pony_remote_enabled() != 0;
    }

    public static var remoteNodes: Int {
        return Int(pony_remote_nodes_count())
    }

    public static var remoteCores: Int {
        return Int(pony_remote_core_count())
    }
    
    public static var appCurrentMemory: UInt64 {
        return UInt64(pony_current_memory())
    }
    
    public static var flynnCurrentMemory: UInt64 {
        return UInt64(pony_mapped_memory())
    }
    
    public static func syslog(_ tag: String, _ message: String) {
        pony_syslog(tag, message)
    }
    
    public static func dns_resolve_cname(domain: String) -> String? {
        guard let stringPtr = pony_dns_resolve_cname(domain) else { return nil }
        let string = String(utf8String: stringPtr)
        free(stringPtr)
        return string
    }
    
    public static func dns_resolve_txt(domain: String) -> String? {
        guard let stringPtr = pony_dns_resolve_txt(domain) else { return nil }
        let string = String(utf8String: stringPtr)
        free(stringPtr)
        return string
    }

    internal static func wakeTimerLoop() {
        timerLoop?.wake()
    }
}
