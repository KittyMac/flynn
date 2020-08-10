<img align="center" src="meta/header.png" >

&nbsp;  

## Quick Start

### Actor-Model Programming

Flynn grafts Actor-Model programming onto Swift, providing a new level of safety and performance for your highly concurrent Swift code.  Flynn is heavily inspired by the [Pony programming language](https://www.ponylang.io). Here's what you need to know:

#### [Actors are concurrency safe Swift classes](docs/ACTOR.md)

Using Actors to separate concurrent logic provides safety, performance, and efficiency.

```swift
class ConcurrentDatastore: Actor {
  // Everything inside this actor is safe and cannot
  // be accessed concurrently by any other thread
  private var storage: [String: String] = [:]
  
  ...
}
```

#### [Behaviors are asynchronous method calls](docs/BEHAVIOR.md)

Actors provide behaviors (which look like normal method calls at the call site) that execute asynchronously from the caller's perspective.

```swift
let datastore = ConcurrentDatastore()
datastore.beStore("SomeKey", "SomeValue")
```

From the Actor's perspective, behaviors execute synchronously (in the same order they are sent for the calling code).

```swift
class ConcurrentDatastore: Actor {
  ...
  // Behaviors are called asynchronously but execute synchronously on the Actor
  private func _beStore(_ key: String, _ value: String) {
    storage[key] = value
  }
}
```

#### [Actors run on schedulers](docs/SCHEDULER.md)

Unlike other attempts to bring Actor-Model programming to Swift, Flynn does not use DispatchQueues. Instead, Flynn includes a modified version of the [Pony language runtime](https://www.ponylang.io/faq/#runtime). This makes actors in Flynn much more light-weight than DispatchQueues; you can have millions of actors all sending messages to each other incredibly efficiently.

#### [Use FlynnLint](docs/FLYNNLINT.md)

Flynn provides the scaffolding for safer concurrency but it relies on you, the developer, to follow the best practices for safe concurrency.  FlynnLint will help you by enforcing those best practices for you at compile time. This keeps you out of numerous concurrency pitfalls by not allowing unsafe code to compile:

![](meta/flynnlint0.png)

In this example, we have a public variable on our Counter Actor. Public variables are not allowed as they can be potentially accessed from other threads, breaking the concurrency safety the Actor-Model paradigm provides us.

## Docs

[Actors](docs/ACTOR.md) - Concurrency safe Swift classes  
[Behaviors](docs/BEHAVIOR.md) - Asynchronous method calls  
[Scheduling](docs/SCHEDULER.md) - How and when Actors execute Behaviors  
[FlynnLint](docs/FLYNNLINT.md) - Protects against data races and other bad things  
[Flowable Actors](docs/FLOWABLE.md) - Easily chainable networks of actors  
[Flynn.Timer](docs/TIMERS.md) - Actor friendly Timers  

## Examples

[Hello World](Examples/HelloWorld/) - You guessed it!  
[Battery Tester](Examples/BatteryTester/) - Use an Actor's core affinity to make smart choices between performance and energy consumption  
[Simple HTTP Server](Examples/SimpleHTTPServer/) - Actors for HTTP connections, Actors as services  
[Concurrent Data SwiftUI](Examples/ConcurrentDataSwiftUI/) - Simple example of using Actor as ObservableObject for SwiftUI

## Projects
[FlynnLint](https://github.com/KittyMac/flynnlint) - FlynnLint uses Flynn to concurrently check your Swift files for Flynn best practices  
[Jukebox](https://github.com/KittyMac/jukebox2) - Linux daemon for running a homebrewed Alexa powered Jukebox  
[Cutlass](https://github.com/KittyMac/cutlass) - Fully concurrent user interfaces using Flynn, [Yoga](https://yogalayout.com) and [Metal](https://developer.apple.com/metal/)  

## Products
<a href="https://apps.apple.com/us/app/pointsman/id1447780441" target="_blank"><img align="center" src="meta/pointsman.png" width="80"></a>
<a href="https://apps.apple.com/us/app/mad-kings-steward/id1461873703" target="_blank"><img align="center" src="meta/madsteward.png" width="80"></a>

Have you released something using Flynn? Let us know!


## Installation

Flynn is a fully compatible with the Swift Package Manager.

### Swift Package Manager

If you use swiftpm, you can add Flynn as a dependency directly to your Package.swift file.

```
dependencies: [
    .package(url: "https://github.com/KittyMac/Flynn.git", .upToNextMinor(from: "0.1")),
],
```

### Xcode

To integrate with Xcode, simply add it as a package dependency by going to

```
File -> Swift Packages -> Add Package Dependency
```

and pasting the url to this repository. Follow the instructions to complete the dependency addition.  [Check the releases page](https://github.com/KittyMac/flynn/releases) for release versions or choose master branch for the bleeding edge.

Flynn is most effective when used with FlynnLint. FlynnLint helps protect you from accidentally introducing data races in your highly concurrent code by enforcing Flynn's best programming practices.  

#### It is HIGHLY RECOMMENDED that you use FlynnLint!

FlynnLint is included in the Flynn repository in the meta folder. Just add a new "Run Script Phase" with:

```bash
FLYNNLINTSWIFTPM=${SRCROOT}/.build/checkouts/flynn/meta/FlynnLint
FLYNNLINTXCODE=${BUILD_ROOT}/../../SourcePackages/checkouts/flynn/meta/FlynnLint

if [ -f "${FLYNNLINTSWIFTPM}" ]; then
    ${FLYNNLINTSWIFTPM} ${SRCROOT}
elif [ -f "${FLYNNLINTXCODE}" ]; then
    ${FLYNNLINTXCODE} ${SRCROOT}
else
    echo "warning: Unable to find FlynnLint, aborting..."
fi
```

![](meta/runphase.png)

If you use other linters (such as SwiftLint), it is recommended that FlynnLint runs before all other linters.

FlynnLint processes any and all directories provided as arguments. If you want to restrict it to a subset of directories, simply list each directory after the call to FlynnLint. For example, if you use swiftpm and your source files are in /Sources and /Tests, then the following would lint just those directories:

```bash
${FLYNNLINTSWIFTPM} ${SRCROOT}/Sources ${SRCROOT}/Tests
```

## License

Flynn is free software distributed under the terms of the MIT license, reproduced below. Flynn may be used for any purpose, including commercial purposes, at absolutely no cost. No paperwork, no royalties, no GNU-like "copyleft" restrictions. Just download and enjoy.

Copyright (c) 2020 [Chimera Software, LLC](http://www.chimerasw.com)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.