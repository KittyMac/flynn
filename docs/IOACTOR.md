# IOActor

An `IOActor` is an actor which owns a thread of its own instead of sharing the
pool of scheduler threads.

## Why

Scheduler threads are a small, fixed resource. An actor which blocks -- a
database round trip, a synchronous file read, a `read()` on a socket -- holds
one of them for the duration, and nobody else gets to run on it. With four
schedulers, four blocking actors stop the world.

The usual way around this is to have the behaviour hand its work to an
`OperationQueue` and return immediately. That works, but it costs a lot:

- The work now runs on a thread which is not the actor's, so touching the
  actor's state from it is a data race. Files which do this end up with a
  `// flynn:ignore Unsafe Self Violation` at the top, which switches off the
  checking for everything else in the file too.
- `then`/`do` stops working across the boundary. The behaviour returns before
  the work happens, so there is nothing for the continuation to attach to.
- The profiler attributes the enqueue, not the query.

An `IOActor` has none of those problems, because it is an ordinary actor in
every respect except where it runs. Behaviours may simply block.

## Use

```swift
class Database: IOActor {
    private var connection: Connection?

    internal func _beConnect(_ info: String) {
        connection = Connection(info)          // blocking connect: fine
    }

    internal func _beQuery(_ sql: String,
                           _ returnCallback: @escaping ([Row]) -> ()) {
        returnCallback(connection?.query(sql) ?? [])   // blocking query: fine
    }
}
```

Everything else behaves exactly as it does for `Actor`: message order,
`then`/`do`, `safeTask`, `unsafeWait()`, `unsafeMessagesCount`, `unsafeCancel()`,
timers, and the profiler.

```swift
let db = Database()
db.beConnect(info)

db.beQuery("select 1", self) { rows in
    // runs on self, as usual
}

db.unsafeWait(100)   // real backpressure: waits on the actor's own queue
```

### Core affinity

The thread's affinity is applied once, when it starts, so it is passed to the
initializer rather than assigned afterwards:

```swift
class Database: IOActor {
    init() {
        super.init(coreAffinity: .onlyEfficiency)
    }
}
```

`Flynn.defaultIOActorAffinity` (`.preferEfficiency`) is used when none is given:
IO work is usually more blocked than busy and has no business displacing compute
on the performance cores. On Apple platforms this maps to a thread QoS of
`QOS_CLASS_UTILITY`; ask for `.onlyPerformance` or `.preferPerformance` to get
`QOS_CLASS_USER_INITIATED` instead.

Setting `unsafeCoreAffinity` on an IOActor after construction has no effect and
prints a warning.

## How it works

`Sources/Pony/dedicated.c`. The thread is a scheduler which owns exactly one
actor: it calls `ponyint_actor_run()` in a loop, keeps going while that returns
a positive value, and parks when the queue drains. The actor is a normal
`pony_actor_t` with one extra field, `dedicated`, which is NULL for everybody
else.

Because the actor is never placed on a scheduler queue, rescheduling it means
waking its thread instead of pushing it. Every reschedule path -- `pony_sendv()`
on `kPushWasEmpty`, `ponyint_resume_actor()`, `ponyint_destroy_actor()` --
funnels through `ponyint_sched_add()`, so that is the only routing change
needed:

```c
if(actor->dedicated != NULL) {
    ponyint_dedicated_wake(actor);
    return;
}
```

The race between a thread deciding to park and a sender deciding to wake it is
closed by `pony_park_t`'s `signalled` flag, the same way it is for scheduler
threads.

Two further places know about dedicated actors:

- `ponyint_sched_wait()` also requires `ponyint_dedicated_is_idle()`, so that
  `Flynn.shutdown()` does not cut off IO which is still in flight.
- `ponyint_sched_shutdown()` calls `ponyint_dedicated_stop_all()` first, since a
  dedicated thread can push onto scheduler queues and must be finished before
  the schedulers it pushes to go away.

Threads are detached rather than joined. Shutdown asks them to stop, then waits
on a count for up to two seconds; a thread sitting inside a blocking call cannot
be interrupted -- that being the entire point -- so past that point it is left
alone rather than having its memory freed underneath it.

## Limits

- A thread parked between messages costs nothing but address space; a thousand
  IOActors still costs a thousand threads.
- `unsafeYield()` is meaningless on an IOActor: there is nobody to yield to.
- An IOActor cannot also be a `MainActor`.
