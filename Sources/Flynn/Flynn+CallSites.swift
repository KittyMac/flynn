import Foundation

extension Flynn {

    /// Optional accounting of live actor messages, grouped by the call site that sent them.
    ///
    /// A message counts as live from the moment it is sent until it has run (or been
    /// discarded), so the count covers messages waiting in a mailbox, messages running
    /// and pending then/do messages. When a process is using far more memory than
    /// expected, `CallSites.top()` shows which call sites are filling the mailboxes.
    ///
    /// Tracking is off by default; when off it costs one Bool check per message.
    public enum CallSites {

        public struct Sample: Codable {
            public let callSite: String
            public let live: Int
        }

        private struct Key: Hashable {
            let file: UInt
            let line: UInt64
        }

        private final class Entry {
            let file: StaticString
            let line: UInt64
            var live: Int = 0
            init(_ file: StaticString, _ line: UInt64) {
                self.file = file
                self.line = line
            }
        }

        private final class Shard {
            let lock = NSLock()
            var entries: [Key: Entry] = [:]
        }

        // Sharded so that hundreds of scheduler threads sending messages from
        // different call sites do not all contend on a single lock.
        private static let shardCount = 64
        private static let shards: [Shard] = (0..<shardCount).map { _ in Shard() }

        public private(set) static var enabled = false

        public static func start() { enabled = true }

        /// Stops tracking new messages. Messages sent while tracking was on are still
        /// released from their counts as they finish.
        public static func stop() { enabled = false }

        /// "file:line", or just the name when there is no line (behaviours called
        /// through a protocol record "Type.beBehaviour (via protocol)" with line 0)
        static func format(_ file: StaticString, _ line: UInt64) -> String {
            return line == 0 ? "\(file)" : "\(file):\(line)"
        }

        @inline(__always)
        private static func key(_ file: StaticString, _ line: UInt64) -> Key {
            let address = file.hasPointerRepresentation ? UInt(bitPattern: file.utf8Start) : 0
            return Key(file: address, line: line)
        }

        @inline(__always)
        private static func shard(_ key: Key) -> Shard {
            return shards[Int((key.file &+ UInt(truncatingIfNeeded: key.line)) % UInt(shardCount))]
        }

        @usableFromInline
        static func retain(_ file: StaticString, _ line: UInt64) {
            let key = key(file, line)
            let shard = shard(key)
            shard.lock.lock()
            if let entry = shard.entries[key] {
                entry.live += 1
            } else {
                let entry = Entry(file, line)
                entry.live = 1
                shard.entries[key] = entry
            }
            shard.lock.unlock()
        }

        @usableFromInline
        static func release(_ file: StaticString, _ line: UInt64) {
            let key = key(file, line)
            let shard = shard(key)
            shard.lock.lock()
            shard.entries[key]?.live -= 1
            shard.lock.unlock()
        }

        /// The call sites with the most live messages, largest first.
        public static func top(_ count: Int = 20) -> [Sample] {
            var samples: [Sample] = []
            for shard in shards {
                shard.lock.lock()
                for entry in shard.entries.values where entry.live > 0 {
                    samples.append(Sample(callSite: format(entry.file, entry.line), live: entry.live))
                }
                shard.lock.unlock()
            }
            samples.sort { $0.live > $1.live }
            return Array(samples.prefix(count))
        }

        /// Total live messages across all tracked call sites.
        public static var totalLive: Int {
            var total = 0
            for shard in shards {
                shard.lock.lock()
                for entry in shard.entries.values { total += entry.live }
                shard.lock.unlock()
            }
            return total
        }
    }
}
