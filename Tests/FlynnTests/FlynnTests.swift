import XCTest

import Flynn

class TestDoubleCallback: Actor {
    internal func _beFunc(_ returnCallback: () -> ()) {
        returnCallback()
        returnCallback()
    }
}

class ThenActor: Actor {
    deinit {
        print("ThenActor - deinit")
    }
    internal func _beFirst(delay: Double, _ returnCallback: @escaping () -> ()) {
        Flynn.Timer(timeInterval: delay, repeats: false, self) { [weak self] timer in
            guard let _ = self else { return }
            returnCallback()
        }
    }
    internal func _beSecond(delay: Double, _ returnCallback: @escaping () -> ()) {
        Flynn.Timer(timeInterval: delay, repeats: false, self) { [weak self] timer in
            guard let _ = self else { return }
            returnCallback()
        }
    }
    internal func _beThird(delay: Double, _ returnCallback: @escaping () -> ()) {
        Flynn.Timer(timeInterval: delay, repeats: false, self) { [weak self] timer in
            guard let _ = self else { return }
            returnCallback()
        }
    }
    internal func _beFourth() {
        print("FOURTH!")
    }
    internal func _beNothing() {
        
    }
}

class ThenNeverActor: Actor {
    deinit {
        print("ThenNeverActor - deinit")
    }
    internal func _beFirst(delay: Double, _ returnCallback: @escaping () -> ()) {
    }
    internal func _beSecond(delay: Double, _ returnCallback: @escaping () -> ()) {
    }
    internal func _beThird(delay: Double, _ returnCallback: @escaping () -> ()) {
    }
}

class ThenActor2: Actor {
    deinit {
        //print("ThenActor2 - deinit")
    }
    internal func _beFirst(_ returnCallback: @escaping () -> ()) {
        //print("1")
        returnCallback()
    }
    internal func _beSecond(_ returnCallback: @escaping () -> ()) {
        //print("2")
        returnCallback()
    }
    internal func _beThird(_ returnCallback: @escaping () -> ()) {
        //print("3")
        returnCallback()
    }
    internal func _beFourth() {
        //print("4")
    }
    
    internal func _beTest(_ returnCallback: @escaping () -> ()) {
        self.beFirst(self) {
        }.then().doSecond(self) {
        }.then().doThird(self) {
        }.then().doFourth().unsafeSend { _ in
            returnCallback()
        }
    }
}

class FlynnTests: XCTestCase {

    override func setUp() {
        Flynn.startup()
    }

    override func tearDown() {
        Flynn.shutdown()
    }
    
    func testDnsResolve() {
        XCTAssertEqual(Flynn.dns_resolve_cname(domain: "staging.rover.smallplanet.com")?.contains("amazonaws.com"), true)
        XCTAssertEqual(Flynn.dns_resolve_cname(domain: "staging.rover.smallplanet.com")?.contains("amazonaws.com"), true)
        XCTAssertEqual(Flynn.dns_resolve_cname(domain: "staging.rover.smallplanet.com")?.contains("amazonaws.com"), true)
        XCTAssertEqual(Flynn.dns_resolve_cname(domain: "staging.rover.smallplanet.com")?.contains("amazonaws.com"), true)
        XCTAssertEqual(Flynn.dns_resolve_cname(domain: "staging.rover.smallplanet.com")?.contains("amazonaws.com"), true)
        XCTAssertEqual(Flynn.dns_resolve_cname(domain: "staging.rover.smallplanet.com")?.contains("amazonaws.com"), true)
        XCTAssertEqual(Flynn.dns_resolve_txt(domain: "staging.rover.smallplanet.com"), nil)
    }
    
    func testArraySync() {
        let numbers = [0,1,2,3,4,5,6,7,8,9]
        var total = 0
        numbers.sync(count: 10) { item, synchronized in
            // this scope happens in parallel on different actors; it would be
            // unsafe to increment total here
            print(item)
            
            // Flynn provides a synchronized closure you can use
            // to put unsafe processing in
            synchronized {
                total += item
            }
        }
        XCTAssertEqual(45, total)
    }
    
    func testArrayAsync() {
        let expectation = XCTestExpectation(description: #function)

        let numbers = [0,1,2,3,4,5,6,7,8,9]
        var total = 0
        
        numbers.async((Flynn.any)) { item, synchronized in
            // this scope happens in parallel on different actors; it would be
            // unsafe to increment total here
            print(item)
            
            // Flynn provides a synchronized closure you can use
            // to put unsafe processing in
            synchronized {
                total += item
            }
        } done: {
            // When all of the processing is complete the done closure is called
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 30.0)

        XCTAssertEqual(45, total)
    }
    
    /*
    func testSuppressCallbackTwice() {
        let test = TestDoubleCallback()
        var count = 0
        test.beFunc(Flynn.any) {
            count += 1
        }
        sleep(2)
        XCTAssertEqual(count, 1)
    }
     */

    func testActorInterruptingThens() {
        let expectation = XCTestExpectation(description: #function)
        
        var results: [String] = []
        
        if true {
            
            for _ in 0..<1 {
                let hack: (Double) -> Double = { v in
                    ThenActor()
                        .beFourth()
                        .then()
                        .doNothing()
                    return v
                }
                
                ThenActor().beFirst(delay: hack(3.0), Flynn.any) {
                    results.append("first")
                }.then().doSecond(delay: hack(2.0), Flynn.any) {
                    results.append("second")
                }.then().doThird(delay: hack(1.0), Flynn.any) {
                    results.append("third")
                    expectation.fulfill()
                }
            }
            
        }
        
        wait(for: [expectation], timeout: 30.0)
        
        XCTAssertEqual(results.joined(separator: ","), "first,second,third")
    }
    
    func testActorThenMultipleActors() {
        // then() allows you to chain behaviour calls to actors when they call their return callback
        let expectation = XCTestExpectation(description: #function)
        
        var results: [Int] = []

        let a = Counter()
        let b = Counter()
        
        a.beInc(1)
        
        a.beGetValue(Flynn.any) { value in
            results.append(value)
        }.then(b).doGetValue(Flynn.any) { value in
            results.append(value)
            expectation.fulfill()
        }
        //.then(a).doGetValue(Flynn.any) { value in
        //    results.append(value)
        //}.then(b).doGetValue(Flynn.any) { value in
        //    results.append(value)
        //}.then(a).doGetValue(Flynn.any) { value in
        //    results.append(value)
        //}.then(b).doGetValue(Flynn.any) { value in
        //    results.append(value)
        //    expectation.fulfill()
        //}
        
        // let thenActor = ThenActor()
        // thenActor.beFirst(delay: 3.0, Flynn.any) {
        //     results.append("first")
        //     //expectation.fulfill()
        // }.then().doSecond(delay: 2.0, Flynn.any) {
        //     results.append("second")
        // }.then(counter).beGetValue(Flynn.any) { value in
        //     results.append("\(value)")
        // }.then(thenActor).doThird(delay: 1.0, Flynn.any) {
        //     results.append("third")
        // }.then().doThird(delay: 1.0, Flynn.any) {
        //     results.append("third")
        // }
        wait(for: [expectation], timeout: 30.0)
        
        XCTAssertEqual(results.map({"\($0)"}).joined(separator: ","), "0,first")

        
    }
    
    func testActorThen() {
        // then() allows you to chain behaviour calls to actors when they call their return callback
        let expectation = XCTestExpectation(description: #function)
        
        var results: [String] = []
        /*
        ThenActor().beFirst(delay: 3.0, Flynn.any) {
            ThenActor()
                .beFourth()
                .then()
                .doFourth()
                .then()
                .doFourth()
                .then()
                .doFourth()
        }
        */
        
        if true {
            // "normal" behaviour calls are put onto the actor's message queue immediately,
            // so these messages will in the order of their delays (third processes in 1 second,
            // second in 2 seconds, first in 3 seconds)
            ThenActor().beFirst(delay: 1.0, Flynn.any) {
                results.append("first")
            }.beSecond(delay: 0.6, Flynn.any) {
                results.append("second")
            }.beThird(delay: 0.3, Flynn.any) {
                results.append("third")
            }
            
            // When we introduce the "then", we are saying that we don't want the next behaviour to
            // be added to this actor until the preceeding behaviour finishes (ie it calls its returnCallback).
            // So in this example we see first in 6 seconds, THEN we see second after 5 seconds, THEN
            // we see third after 4 seconds
            ThenActor().beFirst(delay: 3.0, Flynn.any) {
                results.append("first")
            }.then().doSecond(delay: 2.0, Flynn.any) {
                results.append("second")
            }.then().doThird(delay: 1.0, Flynn.any) {
                results.append("third")
            }
            
            // The "then" allows use to avoid "callback hell". It is syntactically nicer than:
            // let a = ThenActor()
            // a.beFirst(Flynn.any) {
            //     a.beSecond(Flynn.any) {
            //         a.beThird(Flynn.any) {
            //             expectation.fulfill()
            //         }
            //     }
            // }
            
            // Finally, ensure we support "then" on behaviours which do not have a callback (for consistency)
            ThenActor().beFirst(delay: 7.0, Flynn.any) {
                results.append("first")
            }.then().doFourth()
                .then().doThird(delay: 1.0, Flynn.any) {
                results.append("third")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 30.0)
        
        XCTAssertEqual(results.joined(separator: ","), "third,second,first,first,second,third,first,third")
    }
    
    func testActorThen2() {
        let expectation = XCTestExpectation(description: #function)
        
        var count = 1_000_000
        for _ in 0..<1_000_000 {
            if true {
                let a = ThenActor2()
                a.beTest(Flynn.any) {
                    count -= 1
                    if count <= 0 {
                        expectation.fulfill()
                    }
                    //print("really?")
                }
            }
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    func testActorThen3() {
        let expectation = XCTestExpectation(description: #function)
        
        // Note: both "a" and "b" should deinit, but "a" will ONLY
        // deinit if it's "then" (which will never arrive) is cancelled
        if true {
            let a = ThenNeverActor()
            a.beFirst(delay: 5, Flynn.any) {
                
            }.then().doSecond(delay: 5, Flynn.any) {
                
            }
            
            a.unsafeCancel()
            
            a.beFirst(delay: 5, Flynn.any) {
                
            }
        }
        
        if true {
            let b = ThenNeverActor()
            b.beFirst(delay: 5, Flynn.any) {
                
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMultipleDelayedReturns() {
        let expectation = XCTestExpectation(description: #function)

        ActorExhaustive().beNoArgsTwoDelayedReturn(Flynn.any) { (string, int) in
            if string == "Hello World" && int == 42 {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testSyslog() {
        Flynn.syslog("FLYNN", "Hello world")
    }

    func test0() {
        let expectation = XCTestExpectation(description: #function)

        print("before")
        PassToMe().beNone()
        print("after")

        expectation.fulfill()
    }

    func test1() {
        let expectation = XCTestExpectation(description: #function)

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
        let expectation = XCTestExpectation(description: #function)

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
        let expectation = XCTestExpectation(description: #function)
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
        let expectation = XCTestExpectation(description: #function)

        let color: [Float] = [1, 0, 1, 0]
        Image().beSetColor(color)

        Image()
            .beAlpha()
            .beColor()
            .beAlpha()
            .bePath("bundle://image.png")
        expectation.fulfill()
    }
    
    func testMainActor() {
        let expectation = XCTestExpectation(description: #function)
        
        Flynn.main.unsafeSend { _ in
            if Thread.isMainThread {
                expectation.fulfill()
            }
        }
    }

    func testShutdown() {
        let expectation = XCTestExpectation(description: #function)

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
        let expectation = XCTestExpectation(description: #function)

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
        let expectation = XCTestExpectation(description: #function)

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

#if !os(Linux) && !os(Android)
    @available(OSX 10.15, *)
    func testLoadBalancingLong() {
        // 0.141
        // 0.104
        // 0.093
        // 0.086
        // 0.091
        // 0.088
        
        // no locks scheduler
        // 0.076
        
        measure {
            internalTestLoadBalancing(50_000)
        }
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

        let expectation = XCTestExpectation(description: #function)

        let pipeline = Passthrough() |> Array(count: Flynn.cores) { Passthrough() } |> Passthrough() |> Callback({ (args: FlowableArgs) in
            // let s:String = args[x:0]
            // XCTAssertEqual(s.count, 22250000, "load balancing did not contain the expected number of characters")
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
        let expectation = XCTestExpectation(description: #function)

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
        let expectation = XCTestExpectation(description: #function)

        Flynn.Timer(timeInterval: 20.0, repeats: false, Flynn.any, { (_) in })

        // Note: why does sleep() not work in unit tests...
        let start = ProcessInfo.processInfo.systemUptime
        while ProcessInfo.processInfo.systemUptime - start < 1.0 { }

        Flynn.Timer(timeInterval: 1.0, repeats: false, Flynn.any, { (_) in
            expectation.fulfill()
        })

        wait(for: [expectation], timeout: 5.0)
    }

    func testTimerResolution() {
        let expectation = XCTestExpectation(description: #function)

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
        let expectation = XCTestExpectation(description: #function)

        let counter = Counter()

        Flynn.Timer(timeInterval: 0.01, repeats: true, counter, [1])

        Flynn.Timer(timeInterval: 1, repeats: false, counter, { [weak self] (_) in
            guard let _ = self else { return }
            
            counter.beEquals { (value) in
                print(value)
                XCTAssert(value >= 99)
                expectation.fulfill()
            }
        })

        wait(for: [expectation], timeout: 2.0)
    }

    func testSortedTimers() {
        let expectation = XCTestExpectation(description: #function)

        let builder = StringBuilder()

        Flynn.Timer(timeInterval: 0.010, repeats: false, builder, { [weak self] (_) in
            guard let _ = self else { return }
            
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
    
    func testWeakTimersAndDockingActors() {
        if true {
            // normally this actor would dealloc itself when this block is left, however
            // it has been coded to dock itself with Flynn and undock itself after 3 seconds.
            // this feature allows you to spawn actors which don't need to be tethered to a parent
            let _ = WeakTimer() 
            sleep(4)
        }
    }
}
