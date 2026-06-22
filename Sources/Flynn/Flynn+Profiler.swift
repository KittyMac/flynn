import Foundation
import Pony

extension Flynn {

    public enum Profiler {

        public struct Sample: Codable {
            public let type: String
            public let totalNanoseconds: UInt64
            public let batches: UInt64

            public var totalSeconds: Double { Double(totalNanoseconds) / 1_000_000_000.0 }
            public var nanosecondsPerBatch: UInt64 { batches == 0 ? 0 : totalNanoseconds / batches }
        }

        private static let lock = NSLock()
        private static var idsByType: [ObjectIdentifier: Int32] = [:]
        private static var names: [String] = ["untyped"]

        public private(set) static var enabled = false

        public static func start() {
            lock.lock(); enabled = true; lock.unlock()
            pony_profiler_enable(true)
        }

        public static func stop() {
            lock.lock(); enabled = false; lock.unlock()
            pony_profiler_enable(false)
        }

        public static func reset() {
            pony_profiler_reset()
        }

        static func typeID(for actorType: Actor.Type) -> Int32 {
            lock.lock(); defer { lock.unlock() }
            let key = ObjectIdentifier(actorType)
            if let existing = idsByType[key] { return existing }
            let id = Int32(names.count)
            
            guard id < Int32(pony_profiler_max_types()) else { return 0 }
            idsByType[key] = id
            names.append(String(describing: actorType))
            return id
        }

        public static func collect() -> [Sample] {
            lock.lock(); let localNames = names; lock.unlock()

            let maxTypes = Int(pony_profiler_max_types())
            var ns = [UInt64](repeating: 0, count: maxTypes)
            var count = [UInt64](repeating: 0, count: maxTypes)
            pony_profiler_collect(&ns, &count, Int32(maxTypes))

            var samples: [Sample] = []
            for idx in 0..<localNames.count where ns[idx] > 0 {
                samples.append(Sample(type: localNames[idx],
                                      totalNanoseconds: ns[idx],
                                      batches: count[idx]))
            }
            return samples.sorted { $0.totalNanoseconds > $1.totalNanoseconds }
        }

        public static func description(top: Int = Int.max) -> String {
            let samples = collect()
            var result = ""
            guard !samples.isEmpty else {
                return "Flynn.Profiler: no samples (is profiling enabled and actors running?)"
            }
            let total = samples.reduce(0.0) { $0 + $1.totalSeconds }
            
            result.append("Flynn.Profiler — \(samples.count) actor type(s), \(String(format: "%.4f", total))s total\n")
            result.append(String(format: "%-32@  %12@  %10@  %12@\n", "TYPE" as NSString,
                                 "TIME (s)" as NSString, "BATCHES" as NSString, "ns/BATCH" as NSString))
            for sample in samples.prefix(top) {
                let pct = total > 0 ? (sample.totalSeconds / total) * 100.0 : 0
                result.append(String(format: "%-32@  %12.4f  %10llu  %12llu   (%.1f%%)\n",
                                     sample.type as NSString,
                                     sample.totalSeconds,
                                     sample.batches,
                                     sample.nanosecondsPerBatch,
                                     pct))
            }
            return result
        }
    }
}
