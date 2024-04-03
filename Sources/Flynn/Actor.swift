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
        // Cancels all futures and suspends the actor
        safeThenLock.lock()
        for thenPtr in safeThenMessages.values {
            if let _ : ActorMessage = Class(thenPtr) { }
        }
        safeThenMessages.removeAll()
        safeThenLock.unlock()
        
        if let actorPtr = safePonyActorPtr {
            // Note: do not suspend the actor first, as a suspended actor will
            // not be destroyed because it cannot receive its destroy message.
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
        
        #if FLYNN_LEAK_ACTOR
        Actor.record(actor: self)
        #endif
    }

    deinit {
        //print("deinit - Actor")
        safeThenLock.lock()
        for thenPtr in safeThenMessages.values {
            if let _ : ActorMessage = Class(thenPtr) { }
        }
        safeThenMessages.removeAll()
        safeThenLock.unlock()
        
        if let actorPtr = safePonyActorPtr {
            pony_actor_destroy(actorPtr)
        }
        safePonyActorPtr = nil
        
        #if FLYNN_LEAK_ACTOR
        Actor.release(actor: self)
        #endif
    }
    
    @available(iOS 13.0, *)
    @available(macOS 10.15, *)
    @inlinable
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
                Flynn.usleep(50)
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
    @inlinable
    public func unsafeSend(_ block: @escaping PonyBlock) -> Self {
        guard let actorPtr = safePonyActorPtr else {
            print("Warning: unsafeSend called on a cancelled actor")
            return self
        }
        
        let thenId = pony_actor_new_then_id()
        let argumentPtr = Ptr(ActorMessage(block, thenId))
        pony_actor_send_message(actorPtr, argumentPtr, thenId, handleMessage)
        return self
    }
    
    // MARK: - Then -> Do
    @usableFromInline
    internal var safeThenMessages: [UInt64: UnsafeMutableRawPointer] = [:]
    @usableFromInline
    internal let safeThenLock = NSLock()
    
    
    @discardableResult
    @inlinable
    public func unsafeDo(_ block: @escaping PonyBlock,
                         _ file: StaticString = #file,
                         _ line: UInt64 = #line,
                         _ column: UInt64 = #column) -> Self {
        guard let actorPtr = safePonyActorPtr else {
            print("Warning: unsafeSend called on a cancelled actor")
            return self
        }

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
        
        return self
    }
    
    @inlinable
    public func safeThen(_ prevThenId: UInt64?) {
        guard let actorPtr = safePonyActorPtr else { return }
        guard let prevThenId = prevThenId else { return }
        
        safeThenLock.lock(); defer { safeThenLock.unlock() }
        guard let argumentPtr = safeThenMessages.removeValue(forKey: prevThenId) else { return }
        pony_actor_complete_then_message(actorPtr, argumentPtr, handleMessage)
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
