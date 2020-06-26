## Quick Start

### Actor-Model Programming

Flynn grafts Actor-Model programming onto Swift, providing a new level of safety and performance to your concurrent Swift code.  Here's what you need to know:

#### Actors are concurrency safe Swift classes

An Actor is a protected entity for concurrent computation. Outside code can only interact with the actor by sending it messages (called **behaviors**). Actor behaviors are processed sequentially, removing any concurrency concerns inside of the actor. All state associated with actor should be kept private to that actor.

#### Behaviors are asynchronous method calls

Calling a behavior on an actor will always execute asynchronously from the perspective of the caller. Behaviors will also only execute synchronously from the perspect of the callee. If you follow the Flynn best practices (enforced by FlynnLint), your behaviors will start with "be", making it trivial to know which methods are behaviors and thus asynchronous.

#### Actors run cooperatively

Using Flynn you can easily have millions of actors, all executing concurrently in their safe, synchronous walled enviroments. To accomplish this, Flynn creates a scheduler thread per physical CPU core available on the host device. Actors which have work to do (ie behavior calls to process) will be scheduled and run on the scheduler threads. While an actors is running, no other actor can run on that scheduler until it completes. As such, if you are running on a 6-core A12 CPU, then you will only ever have up to six actors executing in parallel at one time. As such, you should avoid long running or blocking operations in actors.

#### Use FlynnLint

Flynn provides the scaffolding for safe concurrency programming; FlynnLint enforces it. For example, for an Actor to be data race free all of its functions and member variables should be private and inaccessible to outside code. Flynn can't stop you from making public functions. FlynnLint can.

Example of a common mistake using Flynn without FlynnLint:

```swift
import Flynn

// NOTE: THIS IS AN UNSAFE EXAMPLE OF FLYNN (FLYNNLINT WILL PROTECT AGAINST THIS)
class Counter: Actor {
  public var count: Int = 0
  lazy var beInc = ChainableBehavior(self) { (_: BehaviorArgs) in
      self.count += 1
  }
}

let counter = Counter()
for _ in 0..<1000000 {
  counter.beInc()
  counter.count += 1
}

// prints 1994681, which is incorrect as we have a data race on count
// since it is accessed by two threads at the same time (this thread
// and the scheduler thread running the actor's beInc() calls
print("count: \(counter.count)")

Flynn.shutdown()
```

FlynnLint will protect you from this and numerous other pitfalls by not allowing unsafe code to compile:

![](meta/flynnlint0.png)


