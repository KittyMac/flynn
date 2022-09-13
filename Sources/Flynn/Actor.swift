import Foundation
import Pony

public typealias PonyBlock = (UnsafeMutableRawPointer?) -> Void
public typealias PonyTaskBlock = (() -> ()) async -> Void

@usableFromInline
typealias AnyPtr = UnsafeMutableRawPointer?

@inlinable @inline(__always)
func UnretainedPtr <T: AnyObject>(_ obj: T) -> AnyPtr {
    return Unmanaged.passUnretained(obj).toOpaque()
}

@inlinable @inline(__always)
func Ptr <T: AnyObject>(_ obj: T) -> AnyPtr {
    return Unmanaged.passRetained(obj).toOpaque()
}

@inlinable @inline(__always)
func Class <T: AnyObject>(_ ptr: AnyPtr) -> T? {
    guard let ptr = ptr else { return nil }
    return Unmanaged<T>.fromOpaque(ptr).takeRetainedValue()
}

@inlinable @inline(__always)
func handleMessage(_ argumentPtr: AnyPtr) {
    if let msg: ActorMessage = Class(argumentPtr) {
        msg.run()
    }
}

@usableFromInline
class ActorMessage {
    
    @usableFromInline
    var block: PonyBlock?

    @usableFromInline
    init(_ block: @escaping PonyBlock) {
        self.block = block
    }

    @inlinable @inline(__always)
    func set(_ block: @escaping PonyBlock) {
        self.block = block
    }

    @inlinable @inline(__always)
    func run() {
        block?(UnretainedPtr(self))
    }
}

open class Actor: Equatable {
    public static func == (lhs: Actor, rhs: Actor) -> Bool {
        return lhs.unsafeUUID == rhs.unsafeUUID
    }

    public let unsafeUUID: String

    @usableFromInline
    var safePonyActorPtr: AnyPtr

    public var unsafeCoreAffinity: CoreAffinity {
        get {
            if let affinity = CoreAffinity(rawValue: pony_actor_getcoreAffinity(safePonyActorPtr)) {
                return affinity
            }
            return .none
        }
        set {
            if pony_core_affinity_enabled() {
                pony_actor_setcoreAffinity(safePonyActorPtr, newValue.rawValue)
            } else {
                pony_actor_setcoreAffinity(safePonyActorPtr, CoreAffinity.none.rawValue)
            }
        }
    }

    public var unsafePriority: Int32 {
        get {
            return pony_actor_getpriority(safePonyActorPtr)
        }
        set {
            pony_actor_setpriority(safePonyActorPtr, newValue)
        }
    }

    public var unsafeMessageBatchSize: Int32 {
        get {
            return pony_actor_getbatchSize(safePonyActorPtr)
        }
        set {
            pony_actor_setbatchSize(safePonyActorPtr, newValue)
        }
    }

    // MARK: - Functions
    public func unsafeWait(_ minMsgs: Int32 = 0) {
        pony_actor_wait(minMsgs, safePonyActorPtr)
    }

    public func unsafeYield() {
        pony_actor_yield(safePonyActorPtr)
    }
    
    public func unsafeSuspend() {
        pony_actor_suspend(safePonyActorPtr)
    }
    
    public func unsafeResume() {
        pony_actor_resume(safePonyActorPtr)
    }

    public var unsafeMessagesCount: Int32 {
        return pony_actor_num_messages(safePonyActorPtr)
    }

    private let initTime: TimeInterval = ProcessInfo.processInfo.systemUptime
    public var unsafeUptime: TimeInterval {
        return ProcessInfo.processInfo.systemUptime - initTime
    }

    public init() {
        Flynn.startup()
        unsafeUUID = UUID().uuidString
        safePonyActorPtr = pony_actor_create()
    }

    deinit {
        //print("deinit - Actor")
        for thenPtr in safeThenMessages.values {
            if let _ : ActorMessage = Class(thenPtr) { }
        }
        safeThenMessages.removeAll()
        
        pony_actor_destroy(safePonyActorPtr)
    }
    
    @available(iOS 13.0, *)
    @available(macOS 10.15, *)
    @inlinable @inline(__always)
    public func safeTask(_ block: @escaping PonyTaskBlock) {
        if pony_actor_is_suspended(safePonyActorPtr) {
            fatalError("safeTask may not be called on an already suspended actor")
        }
        Task {
            while pony_actor_is_suspended(safePonyActorPtr) == false {
                usleep(50)
            }
            await block {
                pony_actor_resume(safePonyActorPtr)
            }
        }
        pony_actor_suspend(safePonyActorPtr)
    }

    public var unsafeStatus: String {
        var scratch = ""
        scratch.append("Actor UUID: \(unsafeUUID)\n")
        scratch.append("Actor Type: \(type(of: self))\n")
        scratch.append("Message Queue Count: \(unsafeMessagesCount)\n")
        scratch.append("Message Batch Size: \(unsafeMessageBatchSize)\n")
        scratch.append("Actor Priority: \(unsafePriority)\n")
        scratch.append("Core Affinity: \(unsafeCoreAffinity)\n")
        return scratch
    }

    // MARK: - Then
    @usableFromInline
    internal var safeThenMessages: [UnsafeMutableRawPointer: UnsafeMutableRawPointer] = [:]
    
    @discardableResult
    @inlinable @inline(__always)
    public func unsafeSend(_ block: @escaping PonyBlock) -> Self {
        let argumentPtr = Ptr(ActorMessage(block))
        if let prevMessage = pony_actor_get_then_argument_ptr() {
            safeThenMessages[prevMessage] = argumentPtr
            pony_actor_then_message(safePonyActorPtr, argumentPtr)
        } else {
            pony_actor_send_message(safePonyActorPtr, argumentPtr, handleMessage)
        }
        return self
    }
    
    @inlinable @inline(__always)
    public func safeThen(_ prevMessage: UnsafeMutableRawPointer?) {
        if let prevMessage = prevMessage,
           let thenPtr = safeThenMessages.removeValue(forKey: prevMessage) {
            pony_actor_send_message(safePonyActorPtr, thenPtr, handleMessage)
        }
    }
    
    @inlinable @inline(__always)
    public var then: Self {
        // on the ponyrt side we store a thread local variable which we now flag so that we
        // know the next behaviour call on this thread should be a then call
        pony_actor_mark_then_argument_ptr()
        return self
    }
}
