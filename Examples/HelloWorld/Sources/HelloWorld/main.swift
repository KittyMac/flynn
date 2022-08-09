import Flynn

class HelloWorld: Actor {
    internal func _bePrint(message: String) {
        print(message)
    }
}

print("synchronous: before")
HelloWorld().bePrint(message: "asynchronous: hello world")
print("synchronous: after")

Flynn.shutdown()
