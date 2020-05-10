# flynn

An actor-model programming paradigm (ala Pony) implementation in Swift.

The Pony programming language has many impressive features which I have enjoyed learning over the past year. However, while bringing Pony to iOS is not only feasible and possible, I want to explore the possibility of the opposite approach and bring some of the key features of Pony to Swift.

## Key Features

• **Actor-Model Programming**  
In Pony you have classes and actors.  Classes are synchronous, Actors are asynchronous.  Generally, you may only interact with actors by calling behaviours on them. Behaviours are messages which get stored in the actor's mailbox and processing synchronously.

• **Reference Capabilities**  
Increased capacity for concurrency without additional safe-guards will only lead to increased capacity for headaches. It is insanely easy to introduce data races and other nasty problems. Some capacity to Pony's reference capabilities would be required to make this possible.

• **Pony Runtime**  
The Pony runtime has an interesting bag of tricks for handling when and how actors to get process. I am unsure at this can influence what we are building here, but I am noting it for completeness.

## The Plan

• **A protocol for Actors**  
  1. Actors can be implemented in Swift by having classes which have a serial dispatch queue.
  2. We need safeguards to disallow calling functions on actors, and only allow sending them messages
  3. Objects sent to an actor must be immuatable OR they must be the only reference to that object in existance (think iso)