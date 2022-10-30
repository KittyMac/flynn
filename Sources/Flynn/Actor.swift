import Foundation
import Pony

public typealias PonyBlock = (UInt64) -> Void
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
    var thenId: UInt64

    @usableFromInline
    init(_ block: @escaping PonyBlock,
         _ thenId: UInt64) {
        self.block = block
        self.thenId = thenId
    }

    @inlinable @inline(__always)
    func set(_ block: @escaping PonyBlock) {
        self.block = block
    }

    @inlinable @inline(__always)
    func run() {
        block?(thenId)
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
            guard safePonyActorPtr != nil else {
                print("Warning: unsafeCoreAffinity called on a cancelled actor")
                return .none
            }
            if let affinity = CoreAffinity(rawValue: pony_actor_getcoreAffinity(safePonyActorPtr)) {
                return affinity
            }
            return .none
        }
        set {
            guard safePonyActorPtr != nil else {
                print("Warning: unsafeCoreAffinity called on a cancelled actor")
                return
            }
            if pony_core_affinity_enabled() {
                pony_actor_setcoreAffinity(safePonyActorPtr, newValue.rawValue)
            } else {
                pony_actor_setcoreAffinity(safePonyActorPtr, CoreAffinity.none.rawValue)
            }
        }
    }

    public var unsafePriority: Int32 {
        get {
            guard safePonyActorPtr != nil else {
                print("Warning: unsafePriority called on a cancelled actor")
                return 0
            }
            return pony_actor_getpriority(safePonyActorPtr)
        }
        set {
            guard safePonyActorPtr != nil else {
                print("Warning: unsafePriority called on a cancelled actor")
                return
            }
            pony_actor_setpriority(safePonyActorPtr, newValue)
        }
    }

    public var unsafeMessageBatchSize: Int32 {
        get {
            guard safePonyActorPtr != nil else {
                print("Warning: unsafeMessageBatchSize called on a cancelled actor")
                return 0
            }
            return pony_actor_getbatchSize(safePonyActorPtr)
        }
        set {
            guard safePonyActorPtr != nil else {
                print("Warning: unsafeMessageBatchSize called on a cancelled actor")
                return
            }
            pony_actor_setbatchSize(safePonyActorPtr, newValue)
        }
    }

    // MARK: - Functions
    public func unsafeWait(_ minMsgs: Int32 = 0) {
        guard safePonyActorPtr != nil else {
            print("Warning: unsafeWait() called on a cancelled actor")
            return
        }
        pony_actor_wait(minMsgs, safePonyActorPtr)
    }

    public func unsafeYield() {
        guard safePonyActorPtr != nil else {
            print("Warning: unsafeYield() called on a cancelled actor")
            return
        }
        pony_actor_yield(safePonyActorPtr)
    }
    
    public func unsafeCancel() {
        // Cancels all futures and suspends the actor
        for thenPtr in safeThenMessages.values {
            if let _ : ActorMessage = Class(thenPtr) { }
        }
        safeThenMessages.removeAll()
        
        if let safePonyActorPtr = safePonyActorPtr {
            pony_actor_suspend(safePonyActorPtr)
            pony_actor_destroy(safePonyActorPtr)
        }
        safePonyActorPtr = nil
    }
    
    public func unsafeSuspend() {
        guard safePonyActorPtr != nil else {
            print("Warning: unsafeSuspend called on a cancelled actor")
            return
        }
        pony_actor_suspend(safePonyActorPtr)
    }
    
    public func unsafeResume() {
        guard safePonyActorPtr != nil else {
            print("Warning: unsafeResume called on a cancelled actor")
            return
        }
        pony_actor_resume(safePonyActorPtr)
    }

    public var unsafeMessagesCount: Int32 {
        guard safePonyActorPtr != nil else {
            print("Warning: unsafeMessagesCount called on a cancelled actor")
            return 0
        }
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
        
        if let safePonyActorPtr = safePonyActorPtr {
            pony_actor_destroy(safePonyActorPtr)
        }
        safePonyActorPtr = nil
    }
    
    @available(iOS 13.0, *)
    @available(macOS 10.15, *)
    @inlinable @inline(__always)
    public func safeTask(_ block: @escaping PonyTaskBlock) {
        guard safePonyActorPtr != nil else {
            print("Warning: safeTask called on a cancelled actor")
            return
        }
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
    internal var safeThenMessages: [UInt64: UnsafeMutableRawPointer] = [:]
    
    @discardableResult
    @inlinable @inline(__always)
    public func unsafeSend(_ block: @escaping PonyBlock) -> Self {
        guard safePonyActorPtr != nil else {
            print("Warning: unsafeSend called on a cancelled actor")
            return self
        }
        
        let thenId = pony_actor_new_then_id()
        let argumentPtr = Ptr(ActorMessage(block, thenId))
        let prevThenId = pony_actor_get_then_id()
        if prevThenId != 0 {
            safeThenMessages[prevThenId] = argumentPtr
            pony_actor_then_message(safePonyActorPtr, thenId)
        } else {
            pony_actor_send_message(safePonyActorPtr, argumentPtr, thenId, handleMessage)
        }
        return self
    }
    
    @inlinable @inline(__always)
    public func safeThen(_ prevThenId: UInt64?) {
        guard safePonyActorPtr != nil else { return }
        
        if let prevThenId = prevThenId,
           let argumentPtr = safeThenMessages.removeValue(forKey: prevThenId) {
            pony_actor_complete_then_message(safePonyActorPtr, argumentPtr, handleMessage)
        }
    }
    
    @inlinable @inline(__always)
    public var then: Self {
        // on the ponyrt side we store a thread local variable which we now flag so that we
        // know the next behaviour call on this thread should be a then call
        pony_actor_mark_then_id()
        return self
    }
}
