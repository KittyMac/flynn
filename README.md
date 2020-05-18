# flynn

<img style="float: left;" src="meta/flynn.png">

An actor-model programming implementation for Swift.

I have spent the last eight months learning and dissecting [Pony](https://www.ponylang.io/discover/#what-is-pony), an open-source, object-oriented, actor-model, capabilities-secure, high-performance programming language. I have grown to love many of the garauntees that Pony provides, and I want to have those capabilities while developing iOS applications.

While [it is possible to compile Pony on iOS](https://github.com/KittyMac/ponyc), interoperability from Pony -> C -> Swift is regrettably annoying. In my opinion this is all on the Swift side, as I have not encountered the same hurdles marrying Pony to Objective-C.  However, Objective-C is dead and Swift is the future, and if I can't have Pony play nicely with Swif then I'd rather have a little bit of Pony in Swift.

Which leads us to Flynn, an attempt to replicate the better parts of the actor/model paradigm Pony provides directly in Swift.

## Key Features

• **Actor-Model Programming**  
In Pony you have classes and actors.  Classes are synchronous, Actors are asynchronous.  Generally, you may only interact with actors by calling behaviours on them. Behaviours are messages which get stored in the actor's mailbox and processing synchronously. Thankfully, there is direct correlation to Swift here.  Actors are classes, and actors have a serial OperationQueue.

• **Reference Capabilities**  
Increased capacity for concurrency without additional safe-guards will only lead to increased capacity for headaches. It is insanely easy to introduce data races and other nasty problems. Swift has copy-on-write protection and other mechanisms, but none of them come close to the compile time garauntees that Pony's reference capabilities system provides. We will have to settle for "making it safer" as opposed to making it "100% safe".

• **Pony Runtime**  
The Pony runtime is an amazing piece of software. Flynn uses a stripped down version of the Pony runtime to schedule and execute actors in a predictable and super performant manner.


## License

Flynn is free software distributed under the terms of the MIT license, reproduced below. Flynn may be used for any purpose, including commercial purposes, at absolutely no cost. No paperwork, no royalties, no GNU-like "copyleft" restrictions. Just download and enjoy.

Copyright (c) 2020 [Chimera Software, LLC](http://www.chimerasw.com)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.