// flynn:ignore Access Level Violation: Unsafe variables should not be used

import Foundation
import Pony

/// An actor which owns a thread of its own instead of sharing the pool of
/// scheduler threads.
///
/// An IOActor is an ordinary actor in every respect except where it runs, so
/// none of that applies: behaviours may simply block.
///
///     class Database: IOActor {
///         private var connection: Connection?
///
///         private func _beQuery(_ sql: String,
///                               _ returnCallback: @escaping ([Row]) -> ()) {
///             // Blocking here costs nobody but this actor.
///             returnCallback(connection?.query(sql) ?? [])
///         }
///     }
open class IOActor: Actor {
    public override init() {
        super.init(dedicatedThread: true,
                   coreAffinity: Flynn.defaultIOActorAffinity)
    }
    public init(coreAffinity: CoreAffinity) {
        super.init(dedicatedThread: true,
                   coreAffinity: coreAffinity)
    }
}
