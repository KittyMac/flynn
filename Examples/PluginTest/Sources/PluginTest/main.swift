import Flynn

class TestActor: Actor {
    internal func _beTest() {
        print("Hello World!")
    }
}

let actor = TestActor()
print("BEFORE")
actor.beTest()
print("AFTER")

Flynn.shutdown()