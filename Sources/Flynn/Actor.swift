// swiftlint:disable identifier_name

import Foundation
import Pony

public typealias PonyBlock = () -> Void
public typealias PonyTaskBlock = (() -> ()) -> Void

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

    @inlinable @inline(__always)
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
        block = nil
    }
}

open class Actor {

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
        pony_actor_destroy(safePonyActorPtr)
    }

    @inlinable @inline(__always)
    public func unsafeSend(_ block: @escaping PonyBlock) {
        pony_actor_send_message(safePonyActorPtr, Ptr(ActorMessage(block)), handleMessage)
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
            block {
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

}
