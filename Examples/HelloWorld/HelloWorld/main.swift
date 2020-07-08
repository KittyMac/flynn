import Flynn

class HelloWorld: Actor {
  lazy var bePrint = Behavior(self) { (args: BehaviorArgs) in
    // flynnlint:parameter String - string to print
    print(args[x:0])
  }
}

print("synchronous: before")
HelloWorld().bePrint("asynchronous: hello world")
print("synchronous: after")

Flynn.shutdown()
