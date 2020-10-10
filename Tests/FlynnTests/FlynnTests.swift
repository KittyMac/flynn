// swiftlint:disable line_length

import XCTest

@testable import Flynn

class FlynnTests: XCTestCase {

    override func setUp() {
        Flynn.startup()
    }

    override func tearDown() {
        Flynn.shutdown()
    }

    func testMultipleDelayedReturns() {
        let expectation = XCTestExpectation(description: "Mutliple delayed returns from Actor behavior")

        ActorExhaustive().beNoArgsTwoDelayedReturn(Flynn.any) { (string, int) in
            if string == "Hello World" && int == 42 {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func test0() {
        let expectation = XCTestExpectation(description: "Warning when passing reference values")

        print("before")
        PassToMe().beNone()
        print("after")

        expectation.fulfill()
    }

    func test1() {
        let expectation = XCTestExpectation(description: "Wait for counter to finish")

        print("start")
        let counter = Counter()
            .beInc(1)
            .beInc(10)
            .beInc(20)
            .beDec(1)
            .beGetValue(Flynn.any) { (value) in
                print("value: \(value)")
                XCTAssertEqual(value, 30, "Counter did not add up to 30")
                expectation.fulfill()
            }

        print(counter.unsafeStatus)
        print("end")
        wait(for: [expectation], timeout: 10.0)
    }

    func test2() {
        let expectation = XCTestExpectation(description: "Wait for string builder to finish")

        let hello = "hello"

        StringBuilder()
            .beAppend(hello)
            .beSpace()
            .beAppend("world")
            .beResult { (value: String) in
                XCTAssertEqual(value, "hello world", "string did not append in the correct order")
                expectation.fulfill()
            }
        wait(for: [expectation], timeout: 10.0)
    }

    func testColor() {
        let expectation = XCTestExpectation(description: "Protocols, extensions etc...")
        let color = Color()
            .beAlpha()
            .beColor()
            .beAlpha()
            .beColor()
            .beAlpha()
            .beColor()
            .beAlpha()
            .beColor()

        color.beGetColor { (color) in
            print("color is \(color)")
        }

        color.beRender()

        expectation.fulfill()
    }

    func testImage() {
        let expectation = XCTestExpectation(description: "Protocols, extensions etc...")

        let color: [Float] = [1, 0, 1, 0]
        Image().beSetColor(color)

        Image()
            .beAlpha()
            .beColor()
            .beAlpha()
            .bePath("bundle://image.png")
        //print(color.safeColorable._color)
        expectation.fulfill()
    }

    func testShutdown() {
        let expectation = XCTestExpectation(description: "Flowable actors")

        let pipeline = Passthrough() |> Uppercase() |> Concatenate() |> Callback({ (args: FlowableArgs) in
            let value: String = args[x:0]
            XCTAssertEqual(value.count, 50000, "load balancing did not contain the expected number of characters")
            expectation.fulfill()
        })

        for num in 0..<50000 {
            if num % 2 == 0 {
                pipeline.beFlow(["x"])
            } else {
                pipeline.beFlow(["o"])
            }
        }
        pipeline.beFlow([])

        Flynn.shutdown()

        wait(for: [expectation], timeout: 10.0)
    }

    func testFlowable() {
        let expectation = XCTestExpectation(description: "Flowable actors")

        let pipeline = Passthrough() |> Uppercase() |> Concatenate() |> Callback({ (args: FlowableArgs) in
            let value: String = args[x:0]
            print(value)
            XCTAssertEqual(value, "HELLO WORLD", "chaining actors did not work as intended")
            expectation.fulfill()
        })

        pipeline.beFlow(["hello"])
        pipeline.beFlow([" "])
        pipeline.beFlow(["world"])
        pipeline.beFlow([])

        wait(for: [expectation], timeout: 10.0)
    }

    private func internalTestLoadBalancing(_ iterations: Int) {
        let expectation = XCTestExpectation(description: "Load balancing")

        let pipeline = Passthrough() |> Array(count: Flynn.cores) { Uppercase() } |> Concatenate() |> Callback({ (args: FlowableArgs) in
            let value: String = args[x:0]
            XCTAssertEqual(value.count, iterations, "load balancing did not contain the expected number of characters")
            expectation.fulfill()
        })

        for _ in 0..<iterations/2 {
            pipeline.beFlow(["x"])
            pipeline.beFlow(["o"])
        }

        pipeline.beFlow([])

        wait(for: [expectation], timeout: 30.0)
    }

#if !os(Linux)
    @available(OSX 10.15, *)
    func testLoadBalancingLong() {
        let options = XCTMeasureOptions()
        options.iterationCount = 100
        self.measure(options: options, block: {
            internalTestLoadBalancing(50_000)
        })
    }
#endif

    func testLoadBalancing() {
        self.measure {
            internalTestLoadBalancing(50_000)
        }
    }

    func testMeasureOverheadAgainstLoadBalancingExample() {
        // What we are attempting to determine is, in this "worst case scenario", how much overhead
        // is there in our actor/model system.
        self.measure {
            let stringX = "x"
            let stringO = "o"
            var combined: String = ""
            for num in 0..<50000 {
                if num % 2 == 0 {
                    combined.append(stringX.uppercased())
                } else {
                    combined.append(stringO.uppercased())
                }
            }
        }
    }

    func testMemoryBloatFromMessagePassing() {

        let expectation = XCTestExpectation(description: "Memory overhead in calling behaviors")

        let pipeline = Passthrough() |> Array(count: Flynn.cores) { Passthrough() } |> Passthrough() |> Callback({ (args: FlowableArgs) in
            //let s:String = args[x:0]
            //XCTAssertEqual(s.count, 22250000, "load balancing did not contain the expected number of characters")
            if args.isEmpty {
                expectation.fulfill()
            }
        })

        for num in 0..<50000 {
            if num % 2 == 0 {
                pipeline.beFlow([1])
            } else {
                pipeline.beFlow([2])
            }
            pipeline.unsafeWait(0)
        }

        pipeline.beFlow([])
        wait(for: [expectation], timeout: 30.0)
    }

    func testMemoryBloatFromMessagePassing2() {
        let expectation = XCTestExpectation(description: "MemoryBloatFromMessagePassing2")

        let counter = Counter()
        for _ in 0..<50000 {
            counter.beInc(1).beInc(1).beInc(1).beInc(1).beInc(1).beInc(1).beInc(1).beInc(1).beInc(1).beInc(1).beInc(1).beInc(1)
            counter.unsafeWait(10)
        }
        counter.beEquals { (value: Int) in
            XCTAssertEqual(value, 50000 * 12, "Counter did not add up to 50000")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testTimerInterrupt() {
        let expectation = XCTestExpectation(description: "Repeating Timer")

        Flynn.Timer(timeInterval: 20.0, repeats: false, Flynn.any, { (_) in })

        // Note: why does sleep() not work in unit tests...
        let start = ProcessInfo.processInfo.systemUptime
        while ProcessInfo.processInfo.systemUptime - start < 1.0 { }

        Flynn.Timer(timeInterval: 1.0, repeats: false, Flynn.any, { (_) in
            expectation.fulfill()
        })

        wait(for: [expectation], timeout: 10.0)
    }

    func testTimerResolution() {
        let expectation = XCTestExpectation(description: "Repeating Timer")

        var count = 0

        var totalTime: TimeInterval = 0
        var startTime = ProcessInfo.processInfo.systemUptime

        Flynn.Timer(timeInterval: 0.2, repeats: true, Flynn.any, { (timer) in

            let now = ProcessInfo.processInfo.systemUptime
            totalTime += now - startTime
            startTime = now

            count += 1
            if count >= 5 {
                timer.cancel()

                print(totalTime)
                XCTAssert(abs(totalTime - 1.0) < 0.001)
                expectation.fulfill()
            }
        })

        wait(for: [expectation], timeout: 2.0)
    }

    func testRepeatingTimer() {
        let expectation = XCTestExpectation(description: "Repeating Timer")

        let counter = Counter()

        Flynn.Timer(timeInterval: 0.01, repeats: true, counter, [1])

        Flynn.Timer(timeInterval: 1, repeats: false, counter, { (_) in
            counter.beEquals { (value) in
                print(value)
                XCTAssert(value >= 99)
                expectation.fulfill()
            }
        })

        wait(for: [expectation], timeout: 2.0)
    }

    func testSortedTimers() {
        let expectation = XCTestExpectation(description: "Sorted Timer")

        let builder = StringBuilder()

        Flynn.Timer(timeInterval: 0.010, repeats: false, builder, { (_) in
            builder.beResult { (value) in
                XCTAssertEqual(value, "123456789", "string did not append in the correct order")
                expectation.fulfill()
            }
        })

        Flynn.Timer(timeInterval: 0.006, repeats: false, builder, ["6"])
        Flynn.Timer(timeInterval: 0.008, repeats: false, builder, ["8"])
        Flynn.Timer(timeInterval: 0.003, repeats: false, builder, ["3"])
        Flynn.Timer(timeInterval: 0.007, repeats: false, builder, ["7"])
        Flynn.Timer(timeInterval: 0.005, repeats: false, builder, ["5"])
        Flynn.Timer(timeInterval: 0.009, repeats: false, builder, ["9"])
        Flynn.Timer(timeInterval: 0.002, repeats: false, builder, ["2"])
        Flynn.Timer(timeInterval: 0.004, repeats: false, builder, ["4"])
        Flynn.Timer(timeInterval: 0.001, repeats: false, builder, ["1"])

        wait(for: [expectation], timeout: 1.0)
    }

    static var allTests = [
        ("test0", test0),
        ("test1", test1),
        ("test2", test2),
        ("testColor", testColor),
        ("testImage", testImage),
        ("testFlowable", testFlowable),
        ("testLoadBalancing", testLoadBalancing),
        ("testMeasureOverheadAgainstLoadBalancingExample", testMeasureOverheadAgainstLoadBalancingExample),
        ("testMemoryBloatFromMessagePassing", testMemoryBloatFromMessagePassing),
        ("testMemoryBloatFromMessagePassing2", testMemoryBloatFromMessagePassing2)
    ]
}
