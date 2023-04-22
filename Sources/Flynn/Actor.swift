import Foundation
import Pony

public typealias PonyBlock = () -> Void
public typealias PonyTaskBlock = (() -> ()) async -> Void

@usableFromInline
typealias AnyPtr = UnsafeMutableRawPointer?

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
        block?()
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
            guard let actorPtr = safePonyActorPtr else {
                print("Warning: unsafeCoreAffinity called on a cancelled actor")
                return .none
            }
            if let affinity = CoreAffinity(rawValue: pony_actor_getcoreAffinity(actorPtr)) {
                return affinity
            }
            return .none
        }
        set {
            guard let actorPtr = safePonyActorPtr else {
                print("Warning: unsafeCoreAffinity called on a cancelled actor")
                return
            }
            if pony_core_affinity_enabled() {
                pony_actor_setcoreAffinity(actorPtr, newValue.rawValue)
            } else {
                pony_actor_setcoreAffinity(actorPtr, CoreAffinity.none.rawValue)
            }
        }
    }

    public var unsafePriority: Int32 {
        get {
            guard let actorPtr = safePonyActorPtr else {
                print("Warning: unsafePriority called on a cancelled actor")
                return 0
            }
            return pony_actor_getpriority(actorPtr)
        }
        set {
            guard let actorPtr = safePonyActorPtr else {
                print("Warning: unsafePriority called on a cancelled actor")
                return
            }
            pony_actor_setpriority(actorPtr, newValue)
        }
    }

    public var unsafeMessageBatchSize: Int32 {
        get {
            guard let actorPtr = safePonyActorPtr else {
                print("Warning: unsafeMessageBatchSize called on a cancelled actor")
                return 0
            }
            return pony_actor_getbatchSize(actorPtr)
        }
        set {
            guard let actorPtr = safePonyActorPtr else {
                print("Warning: unsafeMessageBatchSize called on a cancelled actor")
                return
            }
            pony_actor_setbatchSize(actorPtr, newValue)
        }
    }

    // MARK: - Functions
    public func unsafeWait(_ minMsgs: Int32 = 0) {
        guard let actorPtr = safePonyActorPtr else {
            print("Warning: unsafeWait() called on a cancelled actor")
            return
        }
        pony_actor_wait(minMsgs, actorPtr)
    }

    public func unsafeYield() {
        guard let actorPtr = safePonyActorPtr else {
            print("Warning: unsafeYield() called on a cancelled actor")
            return
        }
        pony_actor_yield(actorPtr)
    }
    
    public func unsafeCancel() {
        if let actorPtr = safePonyActorPtr {
            pony_actor_suspend(actorPtr)
            pony_actor_destroy(actorPtr)
        }
        safePonyActorPtr = nil
    }
    
    public func unsafeSuspend() {
        guard let actorPtr = safePonyActorPtr else {
            print("Warning: unsafeSuspend called on a cancelled actor")
            return
        }
        pony_actor_suspend(actorPtr)
    }
    
    public func unsafeResume() {
        guard let actorPtr = safePonyActorPtr else {
            print("Warning: unsafeResume called on a cancelled actor")
            return
        }
        pony_actor_resume(actorPtr)
    }

    public var unsafeMessagesCount: Int32 {
        guard let actorPtr = safePonyActorPtr else {
            print("Warning: unsafeMessagesCount called on a cancelled actor")
            return 0
        }
        return pony_actor_num_messages(actorPtr)
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
        if let actorPtr = safePonyActorPtr {
            pony_actor_destroy(actorPtr)
        }
        safePonyActorPtr = nil
    }
    
    @available(iOS 13.0, *)
    @available(macOS 10.15, *)
    @inlinable @inline(__always)
    public func safeTask(_ block: @escaping PonyTaskBlock) {
        guard let actorPtr = safePonyActorPtr else {
            print("Warning: safeTask called on a cancelled actor")
            return
        }
        if pony_actor_is_suspended(actorPtr) {
            fatalError("safeTask may not be called on an already suspended actor")
        }
        Task {
            while pony_actor_is_suspended(actorPtr) == false {
                usleep(50)
            }
            await block {
                pony_actor_resume(actorPtr)
            }
        }
        pony_actor_suspend(actorPtr)
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
    
    @discardableResult
    @inlinable @inline(__always)
    public func unsafeSend(_ block: @escaping PonyBlock) -> Self {
        guard let actorPtr = safePonyActorPtr else {
            print("Warning: unsafeSend called on a cancelled actor")
            return self
        }
        
        let argumentPtr = Ptr(ActorMessage(block))
        pony_actor_send_message(actorPtr, argumentPtr, 0, handleMessage)
        return self
    }
}
