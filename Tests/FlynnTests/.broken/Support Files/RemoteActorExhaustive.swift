// swiftlint:disable file_length

import XCTest

@testable import Flynn

// swiftlint:disable function_body_length

// The only purpose of this file is to have one of all combinations of remote
// behaviors to help ensure flynnlint generates them all correctly
class RemoteActorExhaustive: RemoteActor {
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
    internal func _beNoArgsDelayedReturn(_ returnCallback: (String) -> Void) { returnCallback("Hello World") }
    internal func _beOneArgDelayedReturn(_ string: String, _ returnCallback: (String) -> Void) { returnCallback(string) }
    internal func _beNoArgsDelayedReturnNoArgs(_ returnCallback: () -> Void) { returnCallback() }

    internal func _beOneArgTwoDelayedReturn(_ arg0: Int,
                                           _ returnCallback: (Int, String?) -> Void) { returnCallback(arg0, nil) }

    internal func _beArrayReturn(_ returnCallback: ([String]) -> Void) { returnCallback(["hello", "world"]) }

    internal func _beDataReturn(_ returnCallback: (Data) -> Void) { returnCallback(Data()) }
    internal func _beDataArrayReturn(_ returnCallback: ([Data]) -> Void) { returnCallback([Data(), Data()]) }

    internal func _beBoolReturn(_ returnCallback: (Bool) -> Void) { returnCallback(true) }
    internal func _beBoolArrayReturn(_ returnCallback: ([Bool]) -> Void) { returnCallback([false, true]) }

    internal func _beFloatReturn(_ returnCallback: (Float) -> Void) { returnCallback(1.25) }
    internal func _beFloatArrayReturn(_ returnCallback: ([Float]) -> Void) { returnCallback([2.5, 5.75]) }

    /*
    private func _beBinaryFloatArrayReturn(_ returnCallback: ([Float]) -> Void) {
        // flynnlint:codable binary
        returnCallback([2.5, 5.75])
    }
     */
}
