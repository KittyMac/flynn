import Flynn

class TestActor: Actor {
    
    internal func _beTest() {
        print("Hello World!")
    }
    
    private func bar() {
        self._beTest()
    }
}

let actor = TestActor()

print("BEFORE")
actor.beTest()
print("AFTER")

Flynn.shutdown()
