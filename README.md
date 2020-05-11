# flynn

An actor-model programming implementation for Swift.

I have spent the last eight months learning and dissecting [Pony](https://www.ponylang.io/discover/#what-is-pony), an open-source, object-oriented, actor-model, capabilities-secure, high-performance programming language. I have grown to love many of the garauntees that Pony provides, and I want to have those capabilities while developing iOS applications.

While [it is possible to compile Pony on iOS](https://github.com/KittyMac/ponyc), interoperability from C to Swift is surprisingly annoying. In my opinion this is all on the Swift side, as I have not encountered the same hurdles marrying Pony to Objective-C.  However, Objective-C is dead and Swift is the future, and if I can't have Pony play nicely with Swif then I'd rather have a little bit of Pony in Swift.

Which leads us to Flynn, an attempt to replicate the better parts of the Pony programming paradigm directly in Swift.

## Key Features

• **Actor-Model Programming**  
In Pony you have classes and actors.  Classes are synchronous, Actors are asynchronous.  Generally, you may only interact with actors by calling behaviours on them. Behaviours are messages which get stored in the actor's mailbox and processing synchronously. Thankfully, there is direct correlation to Swift here.  Actors are classes, and actors have a serial OperationQueue.

• **Reference Capabilities**  
Increased capacity for concurrency without additional safe-guards will only lead to increased capacity for headaches. It is insanely easy to introduce data races and other nasty problems. Swift has copy-on-write protection and other mechanisms, but none of them come close to the compile time garauntees that Pony's reference capabilities system provides. We will have to settle for "making it safer" as opposed to making it "100% safe".

• **Pony Runtime**  
The Pony runtime has an interesting bag of tricks for handling when and how actors to get process. I am unsure at this point what might be useful to us, but I am noting it for completeness.

## The Plan

• **Actors**

1. Make creating Actors as painless as possible
2. Actors should have "behaviors" which act like Pony behaviors (called asynchronously, executed synchronously)
3. Calling synchronous functions on an Actor should be impossible, but I will settle for "not an easy mistake to make"
4. Actors should be able to yield (stop processing messages for x period of time)
5. Actors should be able to load balance against other actors
6. Actors should be chain-able in a generic manner (ie file reader -> lzip decompress -> tranform -> lzip compress -> file write)