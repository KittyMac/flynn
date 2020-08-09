## Flynn.Timer

While you can use any Timer API you want with Flynn, Flynn.Timer provides a simple and tailored Timer API specifically designed with Actors in mind.

```swift
import Flynn
import Foundation

class HelloWorld: Actor, Timerable {
    private func _bePrint(_ string: String) {
        print(string)
    }

    private func _beTimerFired(_ timer: Flynn.Timer, _ args: TimerArgs) {
        if args.isEmpty {
            print("-")
            return
        }
        if let value = args[0] as? String {
            print(value)
        }
    }
}

let helloWorld = HelloWorld()

let timerA = Flynn.Timer(timeInterval: 1.0, repeats: true, helloWorld)
let timerB = Flynn.Timer(timeInterval: 1.0, repeats: true, helloWorld, ["Hello World"])
var done = false
Flynn.Timer(timeInterval: 10.0, repeats: false) { (_) in
    timerA.cancel()
    timerB.cancel()
    done = true
}

while !done {
    sleep(1)
}

print("Goodbye!")
```

Flynn timers have the following unique characteristics:

1. They are maintained by the Flynn runtime and are not dependent on any other systems (they work without the existance of a RunLoop, for example)
2. They do not maintain a strong reference to any actors, allowing for easy "fire and forget" patterns. If a timer fires and the actor associated with the behavior is gone, the timer will be cancelled automatically. 
3. Timer target Actors must adhere to the Timerable protocol
4. You can supply any arguments to the target using the TimerArgs parameter
5. Timers will NOT stop the Flynn runtime from reaching quiescence; calling Flynn.shutdown() with active times will effectively cancel all existing timers