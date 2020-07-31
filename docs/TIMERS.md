## Flynn.Timer

While you can use any Timer API you want with Flynn, Flynn.Timer provides a simple and tailored Timer API specifically designed with Actors in mind.

```
Flynn.Timer(timeInterval: 1.0, repeats: true, actor.bePrint, ["Hello World"])
```

Flynn timers have the following unique characteristics:

1. They are maintained by the Flynn runtime and are not dependent on any other systems (they work without the existance of a RunLoop, for example)
2. They do not maintain a strong reference to any actors, allowing for easy "fire and forget" patterns. If a timer fires and the actor associated with the behavior is gone, the timer will be cancelled automatically. 
3. They are call behaviors, which garauntees the execution of the behavior to be concurrenctly safe (just like all behaviors)
4. You can supply any arguments to the behavior as a standard BehaviorArgs