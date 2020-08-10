import Foundation

public typealias TimerArgs = [Any?]

public typealias TimerCallback = (_ timer: Flynn.Timer) -> Void

public protocol Timerable: Actor {
    @discardableResult
    func beTimerFired(_ timer: Flynn.Timer, _ args: TimerArgs) -> Self
}

public extension Flynn {

    class Timer {
        var fireTime: TimeInterval = 0.0

        var cancelled: Bool = false

        let timeInterval: TimeInterval
        let repeats: Bool

        weak var target: Timerable?
        var args: TimerArgs = []

        weak var actor: Actor?
        var callback: TimerCallback?

        @discardableResult
        public init(timeInterval: TimeInterval, repeats: Bool, _ target: Timerable) {
            self.timeInterval = timeInterval
            self.repeats = repeats
            self.target = target

            schedule()
        }

        @discardableResult
        public init(timeInterval: TimeInterval, repeats: Bool, _ target: Timerable, _ args: TimerArgs) {
            self.timeInterval = timeInterval
            self.repeats = repeats
            self.target = target
            self.args = args

            schedule()
        }

        @discardableResult
        public init(timeInterval: TimeInterval, repeats: Bool, _ actor: Actor, _ callback: @escaping TimerCallback) {
            self.timeInterval = timeInterval
            self.repeats = repeats
            self.actor = actor
            self.callback = callback

            schedule()
        }

        public func cancel() {
            cancelled = true
        }

        internal func schedule() {
            fireTime = ProcessInfo.processInfo.systemUptime + timeInterval
            Flynn.register(self)
        }

        internal func fire() {
            if cancelled {
                return
            }
            if let target = target {
                target.beTimerFired(self, args)
            } else if let callback = callback, let actor = actor {
                actor.unsafeSend { callback(self) }
            } else {
                cancelled = true
            }

            if !cancelled && repeats {
                schedule()
            }
        }
    }

    internal static func clearRegisteredTimers() {
        registeredTimersQueue.clear()
    }

    private static var registeredTimersQueue = Queue<Timer>(size: 1024,
                                                            manyProducers: true,
                                                            manyConsumers: false)
    internal static func register(_ timer: Timer) {
        registeredTimersQueue.enqueue(timer, sortedBy: { (lhs, rhs) in
            return lhs.fireTime > rhs.fireTime
        })
        wakeTimerLoop()
    }

    @discardableResult
    fileprivate static func checkRegisteredTimers() -> TimeInterval {
        let currentTime = ProcessInfo.processInfo.systemUptime
        var nextTimerMinTime: TimeInterval = 10.0

        var completedTimers: [Flynn.Timer] = []

        registeredTimersQueue.dequeueAny { (timer) in
            let timeDelta = timer.fireTime - currentTime
            if timeDelta < 0 {
                completedTimers.append(timer)
                return true
            }
            if timeDelta < nextTimerMinTime {
                nextTimerMinTime = timeDelta
            }
            return false
        }

        for timer in completedTimers {
            timer.fire()
        }

        if nextTimerMinTime < 0 {
            nextTimerMinTime = 0
        }

        return nextTimerMinTime / 2
    }

    internal class TimerLoop {

        internal var idle: Bool
        internal var running: Bool

    #if os(Linux)
        private lazy var thread = Thread(block: run)
    #else
        private lazy var thread = Thread(target: self, selector: #selector(run), object: nil)
    #endif

        private var waitingForWorkSemaphore = DispatchSemaphore(value: 0)

        init() {
            running = true
            idle = false

            thread.name = "Flynn Timers"
            thread.qualityOfService = .default
            thread.start()
        }

        func wake() {
            waitingForWorkSemaphore.signal()
        }

        @objc func run() {
            while running {
                let timeout = Flynn.checkRegisteredTimers()
                _ = waitingForWorkSemaphore.wait(timeout: DispatchTime.now() + timeout)
            }
        }

        public func join() {
            running = false
            waitingForWorkSemaphore.signal()
            while thread.isFinished == false {
                usleep(1000)
            }
        }

    }
}
