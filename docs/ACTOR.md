# Actors

Think of actors as concurrency safe Swift classes. This safety is accomplished by restricting communication with the actor to behaviors; all other members and functions on an actor should be set to private.  Behavior calls are units of execution which will be processed sequentially but concurrently. Since all functions are private and all behavior code is safely executed, all code inside of the actor is then thread safe.

This is the ideal. Unfortunately, to be 100% thread safe through access restrictions we would need to modify Swift itself.  Since we are not going there, there are a set of best practices that, if you follow them, get you as close to 100% thread safe as is possible.

## Flynnlint Shortcut

If you are using Flynnlint, you can get started with actors very quickly by using the following autocomplete shortcut:

```nameOfActor::ACTOR```

Type that into any Swift file in your XCode project; save and build. When Flynnlint checks the file, it will replace the shortcut with an actor template, like this one:

```
class NameOfActor: Actor {
    lazy var bePrintString = Behavior(self) { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter String - string to print
        let value: String = args[x:0]
        print(value)
    }
}
```

## Actor Best Practices

**Restrict access to variables and functions by making them private**  
*No random thread can read or write your variables or execute your code on their thread through direct access*

**Use behaviors for all interactions with actors**  
*Behaviors ensure code is executed safely and concurrently on your actor*

**Send pass-by-value arguments to behaviors**  
*Pass-by-value types are safe to share between threads and should be preferred use sending data to actors*

**Beware of callback APIs used internally in an actor**  
*Many APIs execute closures as callbacks; if those are executed on a different thread, then two threads are accessing the innards of an actor at the same time (which would be bad). Closure callbacks should immediately call behaviors, keeping thread safety*

These may seem like a lot! Flynnlint will ensure you comply with these best practices at compile time. So if you forget to label an Actor variable as private, it will flag that as an error.

## Flynnlint Enforces Actor Best Practices

Flynnlint ensures that your actor code adheres to the best practices.  For actors specifically, that means ensuring that:

**All actor variables are private**  
*Covered above*

**All actor functions are private**  
*Covered above*

**Actor variables and functions that start with "safe" are "protected"**  
*If all variables and functions in a actor must be private, then class inheritence would be near impossible to do effectively. As such, Flynnlint provides its own implementation pf "protected" access for Actors. Simply start your variable or function with the prefix "safe" and Flynnlint will allow you to make it non-private.  Once it is non-private, it can be called by outside of the main Actor class. Flynnlint will then ensure that the safe variable is only called from a subclass of that actor class, effectively giving actors a "protected" access level*

TODO: insert example

**Actor variables and functions that start with "unsafe" are, well, unsafe!**  
*At the end of the day, you are the developer. If you want to expose access to a variable or function on a actor to be portentially called directly by other threads you can do this by using the prefix "unsafe". As the name implies, all Flynnlint protections are turned off for unsafe variables and functions, and it is up to you to provide any necessary measure so that these can be used safely*

TODO: insert example


## Actor Priority

Actor execute cooperatively on schedulers; there is one scheduler per CPU core. For some actor configurations is may be beneficial to give and actor higher or lower priority to other actors. For example, if you have a pool of producer actors feeding a single consumer actor, you might want to give the consumer actor a higher priority to ensure it receives preferencial scheduling so it can keep up with consumption.

TODO: insert example


## Actor Core Affinity

As there is a scheduler per core, some CPUs support different cores for different purposes. For example, on Apple Silicon there are performance (P) cores and efficiency (E) cores. Each scheduler in Flynn is also labelled as either a performance or efficiency scheduler. An actor can then use its core affinity to hint how it should be scheduled. So if you want to maximize battery life on an iOS device, for example, you can set your actors to only run on the efficiency cores. Or, in our example of many producers to a single consumer, each producer could be set to efficiency cores while the consumer is set to a high performance core.

TODO: insert example

## Actor Yielding

When an actor is scheduled to run, that actor then gets to execute a "batch" of messages from its message queue. In some scenarios, you might want the actor to note execute the entire batch of messages, instead yielding execution after the current behavior call ends. You can do this by calling unsafeYield() on the actor.

TODO: insert example

## Actor Message Count

There are situations when knowing how much work (waiting messages) an actor has can be beneficial. For example, imagine an actor network which reads in chunks of data from a big data stream and passes them through a chain of actors to transform and/or process the data. If the producers can introduce data faster than the processing actors can process it, then the messages will sit in actor messages queues bloating memory until they can get processed. This is typically solved (imperfectly) by a back pressure system where overloading 

TODO: insert example

## Using Protocols with Actors


TODO: insert examples of how to use mixin (ie protocols with state)


