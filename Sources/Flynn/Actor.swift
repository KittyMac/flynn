// swiftlint:disable identifier_name

import Foundation
import Pony

public typealias PonyBlock = () -> Void

typealias AnyPtr = UnsafeMutableRawPointer?

func Ptr <T: AnyObject>(_ obj: T) -> AnyPtr {
    return Unmanaged.passRetained(obj).toOpaque()
}

func Class <T: AnyObject>(_ ptr: AnyPtr) -> T? {
    guard let ptr = ptr else { return nil }
    return Unmanaged<T>.fromOpaque(ptr).takeRetainedValue()
}

private func handleMessage(_ argumentPtr: AnyPtr) {
    if let msg: ActorMessage = Class(argumentPtr) {
        msg.run()
    }
}

private class ActorMessage {
    weak var pool: Queue<ActorMessage>?
    var block: PonyBlock?

    init(_ pool: Queue<ActorMessage>?, _ block: @escaping PonyBlock) {
        self.pool = pool
        self.block = block
    }

    @inline(__always)
    func set(_ block: @escaping PonyBlock) {
        self.block = block
    }

    @inline(__always)
    func run() {
        block?()
        block = nil
        pool?.enqueue(self)
    }

    deinit {
        //print("deinit - ActorMessage")
    }
}

open class Actor {

    private class func startup() {
        Flynn.startup()
    }

    private class func shutdown() {
        Flynn.shutdown()
    }

    private let uuid: String

    private let ponyActorPtr: AnyPtr

    private var poolMessage = Queue<ActorMessage>(size: 128, manyProducers: false, manyConsumers: true)

    @inline(__always)
    private func unpoolMessage(_ block: @escaping PonyBlock) -> ActorMessage {
        if let msg = poolMessage.dequeue() {
            msg.set(block)
            return msg
        }
        return ActorMessage(poolMessage, block)
    }

    public var unsafeCoreAffinity: CoreAffinity {
        get {
            if let affinity = CoreAffinity(rawValue: pony_actor_getcoreAffinity(ponyActorPtr)) {
                return affinity
            }
            return .none
        }
        set {
            pony_actor_setcoreAffinity(ponyActorPtr, newValue.rawValue)
        }
    }

    public var unsafePriority: Int32 {
        get {
            return pony_actor_getpriority(ponyActorPtr)
        }
        set {
            pony_actor_setpriority(ponyActorPtr, newValue)
        }
    }

    public var unsafeMessageBatchSize: Int32 {
        get {
            return pony_actor_getbatchSize(ponyActorPtr)
        }
        set {
            pony_actor_setbatchSize(ponyActorPtr, newValue)
        }
    }

    // MARK: - Functions
    public func unsafeWait(_ minMsgs: Int32 = 0) {
        pony_actor_wait(minMsgs, ponyActorPtr)
    }

    public func unsafeYield() {
        pony_actor_yield(ponyActorPtr)
    }

    public var unsafeMessagesCount: Int32 {
        return pony_actor_num_messages(ponyActorPtr)
    }

    private let initTime: TimeInterval = ProcessInfo.processInfo.systemUptime
    public var unsafeUptime: TimeInterval {
        return ProcessInfo.processInfo.systemUptime - initTime
    }

    public init() {
        Flynn.startup()
        uuid = UUID().uuidString
        ponyActorPtr = pony_actor_create()
    }

    deinit {
        //print("deinit - Actor")
        pony_actor_destroy(ponyActorPtr)
    }

    public func unsafeSend(_ block: @escaping PonyBlock) {
        pony_actor_send_message(ponyActorPtr, Ptr(unpoolMessage(block)), handleMessage)
    }

}
