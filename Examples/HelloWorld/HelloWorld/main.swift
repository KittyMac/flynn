import Flynn

// swiftlint:disable force_cast

class HelloWorld: Actor {
    var safeValue: Int = 5
}

class GoodbyeWorld: HelloWorld {
    override init() {
        super.init()
        self.safeValue = 42
    }
}

let hello = HelloWorld()
hello.safeValue = 7





