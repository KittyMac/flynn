
import XCTest

@testable import Flynn

/*
class Counter: Actor {
    private var counter: Int = 0

    private func apply(_ value: Int) {
        counter += value
    }

    public var unsafeValue: Int {
        return counter
    }

    lazy var beHello = ChainableBehavior(self) { (args: BehaviorArgs) in
        // flynnlint:parameter String - who is saying hello!
        print("hello world from " + args[x:0])
    }

    lazy var beInc = ChainableBehavior(self) { [unowned self] (args: BehaviorArgs) in
         // flynnlint:parameter Int - amount to increment by
        self.apply(args[x: 0])
    }
    lazy var beDec = ChainableBehavior(self) { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter Int - amount to decrement
        self.apply(-(args[x: 0]))
    }
    lazy var beEquals = ChainableBehavior(self) { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter ((Int) -> Void) - on complete closure
        let callback: ((Int) -> Void) = args[x:0]
        callback(self.counter)
    }
}
*/
