// flynn:ignore Access Level Violation: Unsafe variables should not be used

import Foundation
import Pony

public typealias PonyBlock = (UInt64) -> Void
public typealias PonyTaskBlock = (() -> ()) async -> Void

@usableFromInline
typealias AnyPtr = UnsafeMutableRawPointer?

@inlinable
func Ptr <T: AnyObject>(_ obj: T) -> AnyPtr {
    return Unmanaged.passRetained(obj).toOpaque()
}

@inlinable
func Class <T: AnyObject>(_ ptr: AnyPtr) -> T? {
    guard let ptr = ptr else { return nil }
    return Unmanaged<T>.fromOpaque(ptr).takeRetainedValue()
}

@inlinable
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

    @inlinable
    func set(_ block: @escaping PonyBlock) {
        self.block = block
    }

    @inlinable
    func run() {
        block?(thenId)
    }
}

open class Actor: Equatable, Hashable {
    #if FLYNN_LEAK_ACTOR
    struct WeakActor {
        weak var actor: Actor?
    }
    private static var recordedActors: [String: WeakActor] = [:]
    private static var recordedActorsLock = NSLock()
    
    private static func releaseWeakActors() {
        // Note: it is important we delay the deinit-ing of actors until we are outside
        // the lock/unlock, as deinit-ing an actor can lead to another actor needing
        // to be freed before we give up the lock
        var weakActors: [Actor] = []
        recordedActorsLock.lock()
        for recordedActor in recordedActors {
            guard let recordedActor = recordedActor.value.actor else { continue }
            weakActors.append(recordedActor)
        }
        recordedActors = recordedActors.filter { $0.value.actor != nil }
        recordedActorsLock.unlock()
        weakActors.removeAll()
    }
    
    public static func record(actor: Actor) {
        releaseWeakActors()
        
        recordedActorsLock.lock()
        recordedActors[actor.unsafeUUID] = WeakActor(actor: actor)
        recordedActorsLock.unlock()
    }
    public static func release(actor: Actor) {
        releaseWeakActors()
        
        recordedActorsLock.lock()
        recordedActors[actor.unsafeUUID] = nil
        recordedActorsLock.unlock()
    }
    public static func printLeakedActors() {
        releaseWeakActors()
        
        recordedActorsLock.lock()
        var actorCounts: [String: Int] = [:]
        for weakActor in recordedActors.values {
            guard let actor = weakActor.actor else { continue }
            let log = "\(actor)"
            actorCounts[log] = (actorCounts[log] ?? 0) + 1
        }
        for (log, count) in actorCounts {
            print("\(count) \(log)")
        }
        recordedActorsLock.unlock()
    }
    #endif
    
    
    public static func == (lhs: Actor, rhs: Actor) -> Bool {
        return lhs.unsafeUUID == rhs.unsafeUUID
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(unsafeUUID)
    }

    public let unsafeUUID: String
    
    private var _ponyActorPtr: AnyPtr
    
    private let _ponyActorLock = NSLock()
    
    @discardableResult
    internal func safeWithActorPtr<R>(_ body: (UnsafeMutableRawPointer) -> R) -> R? {
        _ponyActorLock.lock()
        defer { _ponyActorLock.unlock() }
        guard let actorPtr = _ponyActorPtr else { return nil }
        return body(actorPtr)
    }
    
    private func claimActorPtr() -> UnsafeMutableRawPointer? {
        _ponyActorLock.lock()
        defer { _ponyActorLock.unlock() }
        let ptr = _ponyActorPtr
        _ponyActorPtr = nil
        return ptr
    }

    public var unsafeCoreAffinity: CoreAffinity {
        get {
            guard let raw = safeWithActorPtr({ pony_actor_getcoreAffinity($0) }) else {
                print("Warning: unsafeCoreAffinity called on a cancelled actor")
                return .none
            }
            return CoreAffinity(rawValue: raw) ?? .none
        }
        set {
            let result: Void? = safeWithActorPtr { actorPtr in
                if pony_core_affinity_enabled() {
                    pony_actor_setcoreAffinity(actorPtr, newValue.rawValue)
                } else {
                    pony_actor_setcoreAffinity(actorPtr, CoreAffinity.none.rawValue)
                }
            }
            if result == nil {
                print("Warning: unsafeCoreAffinity called on a cancelled actor")
            }
        }
    }

    public var unsafePriority: Int32 {
        get {
            guard let val = safeWithActorPtr({ pony_actor_getpriority($0) }) else {
                print("Warning: unsafePriority called on a cancelled actor")
                return 0
            }
            return val
        }
        set {
            if safeWithActorPtr({ pony_actor_setpriority($0, newValue) }) == nil {
                print("Warning: unsafePriority called on a cancelled actor")
            }
        }
    }

    public var unsafeMessageBatchSize: Int32 {
        get {
            guard let val = safeWithActorPtr({ pony_actor_getbatchSize($0) }) else {
                print("Warning: unsafeMessageBatchSize called on a cancelled actor")
                return 0
            }
            return val
        }
        set {
            if safeWithActorPtr({ pony_actor_setbatchSize($0, newValue) }) == nil {
                print("Warning: unsafeMessageBatchSize called on a cancelled actor")
            }
        }
    }

    // MARK: - Functions
    public func unsafeWait(_ minMsgs: Int32 = 0) {
        if safeWithActorPtr({ pony_actor_wait(minMsgs, $0) }) == nil {
            print("Warning: unsafeWait() called on a cancelled actor")
        }
    }

    public func unsafeYield() {
        if safeWithActorPtr({ pony_actor_yield($0) }) == nil {
            print("Warning: unsafeYield() called on a cancelled actor")
        }
    }
    
    public func unsafeCancel() {
        // Drain pending then-messages under the then-lock. Collect the pointers
        // first, then release them outside the lock to avoid re-entrant locking
        // if a released ActorMessage triggers further actor work.
        let pendingPtrs: [UnsafeMutableRawPointer]
        safeThenLock.lock()
        pendingPtrs = Array(safeThenMessages.values)
        safeThenMessages.removeAll()
        safeThenLock.unlock()
        
        for thenPtr in pendingPtrs {
            // Consume the +1 retain from passRetained to avoid a leak.
            let _: ActorMessage? = Class(thenPtr)
        }
        
        // Atomically claim the pointer so that deinit won't double-destroy.
        if let actorPtr = claimActorPtr() {
            pony_actor_destroy(actorPtr)
        }
    }
    
    public func unsafeSuspend() {
        if safeWithActorPtr({ pony_actor_suspend($0) }) == nil {
            print("Warning: unsafeSuspend called on a cancelled actor")
        }
    }
    
    public func unsafeResume() {
        if safeWithActorPtr({ pony_actor_resume($0) }) == nil {
            print("Warning: unsafeResume called on a cancelled actor")
        }
    }

    public var unsafeMessagesCount: Int32 {
        guard let val = safeWithActorPtr({ pony_actor_num_messages($0) }) else {
            print("Warning: unsafeMessagesCount called on a cancelled actor")
            return 0
        }
        return val
    }

    private let initTime: TimeInterval = ProcessInfo.processInfo.systemUptime
    public var unsafeUptime: TimeInterval {
        return ProcessInfo.processInfo.systemUptime - initTime
    }

    public init() {
        Flynn.startup()
        unsafeUUID = UUID().uuidString
        _ponyActorPtr = pony_actor_create()
        
        #if FLYNN_LEAK_ACTOR
        Actor.record(actor: self)
        #endif
    }

    deinit {
        let pendingPtrs: [UnsafeMutableRawPointer]
        safeThenLock.lock()
        pendingPtrs = Array(safeThenMessages.values)
        safeThenMessages.removeAll()
        safeThenLock.unlock()
        
        for thenPtr in pendingPtrs {
            let _: ActorMessage? = Class(thenPtr)
        }
        
        // claimActorPtr ensures no double-destroy if unsafeCancel already ran.
        if let actorPtr = claimActorPtr() {
            pony_actor_destroy(actorPtr)
        }
        
        #if FLYNN_LEAK_ACTOR
        Actor.release(actor: self)
        #endif
    }
    
    @available(iOS 13.0, *)
    @available(macOS 10.15, *)
    public func safeTask(_ block: @escaping PonyTaskBlock) {
        let suspended = safeWithActorPtr { actorPtr -> Bool in
            if pony_actor_is_suspended(actorPtr) {
                return true
            }
            return false
        }
        
        guard let isSuspended = suspended else {
            print("Warning: safeTask called on a cancelled actor")
            return
        }
        if isSuspended {
            fatalError("safeTask may not be called on an already suspended actor")
        }
        
        Task { [weak self] in
            guard let self = self else { return }
            // Poll until the actor is actually suspended before running the async block
            while true {
                let isSusp = self.safeWithActorPtr({ pony_actor_is_suspended($0) }) ?? true
                if isSusp { break }
                Flynn.usleep(50)
            }
            await block {
                self.safeWithActorPtr { pony_actor_resume($0) }
            }
        }
        safeWithActorPtr { pony_actor_suspend($0) }
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
    public func unsafeSend(_ block: @escaping PonyBlock) -> Self {
        let sent: Void? = safeWithActorPtr { actorPtr in
            let thenId = pony_actor_new_then_id()
            let argumentPtr = Ptr(ActorMessage(block, thenId))
            pony_actor_send_message(actorPtr, argumentPtr, thenId, handleMessage)
        }
        if sent == nil {
            print("Warning: unsafeSend called on a cancelled actor")
        }
        return self
    }
    
    // MARK: - Then -> Do
    @usableFromInline
    internal var safeThenMessages: [UInt64: UnsafeMutableRawPointer] = [:]
    @usableFromInline
    internal let safeThenLock = NSLock()
    
    
    @discardableResult
    public func unsafeDo(_ block: @escaping PonyBlock,
                         _ file: StaticString = #file,
                         _ line: UInt64 = #line,
                         _ column: UInt64 = #column) -> Self {
        let sent: Void? = safeWithActorPtr { actorPtr in
            let thenId = pony_actor_new_then_id()
            let argumentPtr = Ptr(ActorMessage(block, thenId))
            let prevThenId = pony_actor_get_then_id(file.utf8Start, line, column)
            
            guard prevThenId != 0 else {
                fatalError("do called but there is not a previous then to attach to at \(file):\(line)")
            }
            
            safeThenLock.lock()
            safeThenMessages[prevThenId] = argumentPtr
            safeThenLock.unlock()
            pony_actor_then_message(actorPtr, thenId)
        }
        if sent == nil {
            print("Warning: unsafeSend called on a cancelled actor")
        }
        return self
    }
    
    public func safeThen(_ prevThenId: UInt64?) {
        guard let prevThenId = prevThenId else { return }
        
        // Retrieve the pending then-message under the then-lock, then dispatch
        // it under the actor-ptr lock. This ordering (then-lock first, actor-lock
        // second) must be consistent everywhere to avoid deadlocks.
        safeThenLock.lock()
        let argumentPtr = safeThenMessages.removeValue(forKey: prevThenId)
        safeThenLock.unlock()
        
        guard let argumentPtr = argumentPtr else { return }
        
        let dispatched: Void? = safeWithActorPtr { actorPtr in
            pony_actor_complete_then_message(actorPtr, argumentPtr, handleMessage)
        }
        
        // If the actor was already cancelled/destroyed, we still own the +1
        // retain on the ActorMessage — release it to avoid a leak.
        if dispatched == nil {
            let _: ActorMessage? = Class(argumentPtr)
        }
    }
    
    @inlinable
    public func then(_ file: StaticString = #file,
                     _ line: UInt64 = #line,
                     _ column: UInt64 = #column) -> Self {
        // on the ponyrt side we store a thread local variable which we now flag so that we
        // know the next behaviour call on this thread should be a then call
        
        // We need the file and line to create a "unique" value for which we can
        // associated the correct call that happens right after the "then"
        // The ruleset right now is that it must be the same file and it
        // must be the same line
        pony_actor_mark_then_id(file.utf8Start, line, column)
        return self
    }
    
    @inlinable
    public func then<T:Actor>(_ actor: T,
                              _ file: StaticString = #file,
                              _ line: UInt64 = #line,
                              _ column: UInt64 = #column) -> T {
        // on the ponyrt side we store a thread local variable which we now flag so that we
        // know the next behaviour call on this thread should be a then call
        
        // We need the file and line to create a "unique" value for which we can
        // associated the correct call that happens right after the "then"
        // The ruleset right now is that it must be the same file and it
        // must be the same line
        pony_actor_mark_then_id(file.utf8Start, line, column)
        return actor
    }
}
