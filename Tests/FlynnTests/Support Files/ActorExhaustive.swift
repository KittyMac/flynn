import XCTest
@testable import Flynn

// The only purpose of this file is to have one of all combinations of remote
// behaviors to help ensure flynnlint generates them all correctly
class ActorExhaustive: Actor {
    internal func _beNoArgsNoReturn() { }
    internal func _beNoArgsVoidReturn() { }
    internal func _beNoArgsOneReturn() -> Int { return 0 }

    internal func _beOneArgNoReturn(_ arg0: Int) { }
    internal func _beOneArgOneReturn(_ arg0: Int) -> Int { return arg0 }

    internal func _beTwoArgsNoReturn(_ arg0: Int, _ arg1: String?) { }
    internal func _beTwoArgsOptionalReturn(_ arg0: Int, _ arg1: String?) -> String? { return arg1 }

    internal func _beOneArgTwoReturn(_ arg0: Int) -> (Int, String?) { return (arg0, nil) }

    // adding a returnCallback to your behavior signals FlynnLint that this
    // behavior you want to be able to respond to at some point in the future
    // (and not with a direct return value). Simply including this parameter
    // as the last parameter to the behavior is enough to let FlynnLint know
    // what to do.
    internal func _beNoArgsDelayedReturnNoArgs(_ returnCallback: () -> Void) { returnCallback() }

    internal func _beNoArgsDelayedReturn(_ returnCallback: (String) -> Void) { returnCallback("Hello World") }
    internal func _beOneArgDelayedReturn(_ string: String, _ returnCallback: (String) -> Void) { returnCallback(string) }

    internal func _beNoArgsTwoDelayedReturn(_ returnCallback: (String, Int) -> Void) { returnCallback("Hello World", 42) }
    internal func _beOneArgTwoDelayedReturn(_ string: String, _ returnCallback: (String, Int) -> Void) { returnCallback(string, 42) }

    internal func _beArrayReturn(_ returnCallback: ([String], Int) -> Void) { returnCallback(["hello", "world"], 42) }

}
