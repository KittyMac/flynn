## SCHEDULING

Flynn is heavily inspired by the [Pony programming language](https://www.ponylang.io).  More than that, Flynn uses a modified version of the Pony runtime to provide high performance actor scheduling and messaging. This document describes the basics of how the Flynn runtime (and, by extension, the Pony runtime) works.

If you have read the other documentation sections, then you know that Actors are concurrency safe entities which communicate through Behaviors. When a Behavior is called, a message is added to the actor's "message queue".  If the message queue was empty at the time it was added, then the Actor needs to be scheduled for execution. Here is where we pick up the story.

When Flynn starts up (either by explicitly calling ```Flynn.startup()``` or automatically when the first actor is initialized), the Flynn runtime will spawn a number of Schedulers. 

1. One scheduler per CPU core
2. "Efficiency" and "performance" schedulers
3. Flynn runtime is a cooperative multitasking system
4. Schedulers are responsible for running Actors


### One scheduler per CPU core

A single scheduler is spawned per CPU core. On Apple hardware, this will be **one per physical core**. On Linux, it will be the number returned by ```ProcessInfo.processInfo.processorCount```. This mechanism of schedulers and actors is superior to other Swift Actor-Model implementations, which often use a DispatchQueue per actor. With Flynn, you can have millions of actors but the thread cost is constant to the number of cores you have.

### "Efficiency" and "performance" schedulers

Starting with the A10 chip, Apple Silicon has had the concept of "E cores" and "P cores" ("efficiency cores" and "performance cores"). Flynn supports this architecture through the concept of "core affinity".  Each scheduler is assigned the "affinity" of the core it was spawned for; so Flynn has "efficiency" schedulers and "performance" schedulers. Technically, this is implemented by the scheduler thread's QoS being set to ```.utility``` for efficiency and ```.userInitiated``` for performance.

**Note: Once Apple Silicon comes to macOS default core affinities will be updated**

Each Actor has a core affinity (accessbile through ```unsafeCoreAffinity``` or globally though ```Flynn.defaultActorAffinity```).  When running on iOS, the default core affinity is ```.preferEfficiency```. This means actors will be scheduled on the efficiency schedulers first, and if there are none available they will be scheduled on the performance schedulers.  For non-iOS builds, the default affinity is ```.none```, which means it doesn't matter which scheduler the actor is assigned to.

### Flynn is a cooperative multitasking system

A running Actor cannot be preempted by the scheduler it is running on. As such, if an actor hard loops that scheduler is effectively dead and no more actors will get to run on it. As such, it is considered best practice to limit a behavior's tasks to non-waiting tasks.  Avoid lengthy blocking operations if you can.  With a little care you can use GCD or other asynchronous APIs internal to an actor safely to avoid blocking operations.


### Schedulers are responsible for running Actors

When an actor needs scheduling, Flynn adds the actor the end of a scheduler's actor queue and then wakes it up if the scheduler is idle. The scheduler then pops the next actor off of its queue and tells the actor to run.  The actor will execute a number of messages from its own message queue, and then return to the scheduler telling it whether it should be rescheduled or not.

If the actor needs to be rescheduled, then scheduler pops the next actor off of its queue.  If there is, then it compares that actor's priority to the priority of the actor which just finished. If the current actor's priority is higher, then the scheduler re-runs the current actor and asks Flynn to reschedule the other actor on a different scheduler.

If an actor with a core affinity incompatible with the scheduler's core affinity is encountered, the scheduler is responsible for rescheduling it.