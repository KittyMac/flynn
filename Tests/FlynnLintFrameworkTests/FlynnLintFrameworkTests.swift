//
//  FlynnLintTests.swift
//  FlynnLintTests
//
//  Created by Rocco Bowling on 5/31/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import XCTest
@testable import FlynnLintFramework

class FlynnLintTests: XCTestCase {
    var output = "/tmp/flynnlint"
    var packageRoot = ""
    
    override func setUpWithError() throws {
        packageRoot = #file.replacingOccurrences(of: "/Tests/FlynnLintFrameworkTests/FlynnLintFrameworkTests.swift", with: "")
    }

    override func tearDownWithError() throws { }

    /*
    func testSO10() throws {
        let flynnlint = FlynnLint()
        flynnlint.process(input: "/Volumes/Development/Development/chimerasw2/starbaseorion10/Server/.build/checkouts/Picaroon",
                          output: output)
        flynnlint.process(input: "/Volumes/Development/Development/chimerasw2/starbaseorion10/Server/Sources",
                          output: output)
        flynnlint.process(input: "/Volumes/Development/Development/chimerasw2/starbaseorion10/Server/Tests",
                          output: output)
        flynnlint.finish()
    }
    
    func testFlynn() throws {
        let flynnlint = FlynnLint()
        flynnlint.process(input: "/Users/rjbowli/Development/chimerasw/Flynn/Tests",
                          output: output)
        flynnlint.process(input: "/Users/rjbowli/Development/chimerasw/Flynn/Sources",
                          output: output)
        flynnlint.finish()
    }

    func testFlynnLint() throws {
        let flynnlint = FlynnLint()
        flynnlint.process(output: output,
                          input: "/Users/rjbowli/Development/chimerasw/Flynnlint/Sources")
        flynnlint.process(output: output,
                          input: "/Users/rjbowli/Development/chimerasw/Flynnlint/Tests")
        flynnlint.finish()
    }

    func testBatteryTester() throws {
        let flynnlint = FlynnLint()
        flynnlint.process(output: output,
                          input: "/Users/rjbowli/Development/chimerasw/Flynn/Examples/BatteryTester/BatteryTester")
        flynnlint.finish()
    }
    
    func testHelloWorld() throws {
        let flynnlint = FlynnLint()
        flynnlint.process(output: output,
                          input: "/Users/rjbowli/Development/chimerasw/Flynn/Examples/HelloWorld/HelloWorld")
        flynnlint.finish()
    }

    func testCutlass() throws {
        let flynnlint = FlynnLint()
        flynnlint.process(output: output,
                          input: "/Volumes/Development/Development/chimerasw2/cutlass/Cutlass")
        flynnlint.finish()
    }
    
    func testSOServerFramework() throws {
        let flynnlint = FlynnLint()
        flynnlint.process(output: output,
                          input: "/Volumes/Development/Development/chimerasw2/starbaseorion10/Server/Sources/SOServerFramework")
        flynnlint.finish()
    }

    func testOneRuleOneCode() throws {
        let rule = PrivateFunctionInActorRule()
        XCTAssert(rule.test("""
            class TestActor: Actor {
                private var string: String = ""

                private func _bePrint() {
                    print("Hello world")
                }
            }
        """))
    }
    
    func testAllRulesOneCode() throws {
        let code = """
            class TestActor: Actor {
                private var string: String = ""

                private func _bePrint() {
                    print("Hello world")
                }
            }
        """
        let rules = Ruleset()
        for rule in rules.all {
            XCTAssert(rule.test(code))
        }
    }

    func testOneRule() throws {
        let rule = PrivateFunctionInRemoteActorRule()
        XCTAssert(rule.test())
    }

    func testAllRules() throws {
        let rules = Ruleset()
        for rule in rules.all {
            XCTAssert(rule.test())
        }
    }
    
    func testCodeGen() throws {
        let flynnlint = FlynnLint()
        flynnlint.process(output: output,
                          input: "/Users/rjbowli/Development/chimerasw/Flynn/Tests/FlynnTests/Support Files")
        flynnlint.finish()
    }

    func testSampleSet() throws {
        let flynnlint = FlynnLint()
        flynnlint.process(output: output,
                          input: "/Users/rjbowli/Development/chimerasw/Flynnlint/Tests/sample")
        flynnlint.finish()
    }

    func testPerformanceSet() throws {
        measure {
            let flynnlint = FlynnLint()
            flynnlint.process(output: output,
                              input: "/Users/rjbowli/Development/chimerasw/Flynnlint/Tests/benchmark")
            flynnlint.finish()
        }
    }
/*
    func testReleaseCrashTest() throws {
        for _ in 0..<1000 {
            let task = Process()
            task.launchPath = "/Users/rjbowli/Development/chimerasw/Flynnlint/.build/release/flynnlint"
            task.arguments = ["/Users/rjbowli/Development/chimerasw/Flynnlint/Tests/benchmark"]
            task.launch()
            task.waitUntilExit()
            XCTAssert(task.terminationStatus == 0)
        }
    }
    */
    func testReleasePerformanceSet() throws {
        measure {
            let task = Process()
            task.launchPath = "/Users/rjbowli/Development/chimerasw/Flynnlint/.build/release/flynnlint"
            task.arguments = ["/Users/rjbowli/Development/chimerasw/Flynnlint/Tests/benchmark"]
            task.launch()
            task.waitUntilExit()
            //XCTAssert(task.terminationStatus == 0)
        }
    }

    func testSwiftLintPerformanceSet() throws {
        measure {
            let task = Process()
            task.launchPath = "/usr/local/bin/swiftlint"
            task.arguments = ["--path", "/Users/rjbowli/Development/chimerasw/Flynnlint/Tests/benchmark"]
            task.launch()
            task.waitUntilExit()
            //XCTAssert(task.terminationStatus == 0)
        }
    }
    
    func testLocalDir() throws {
        let flynnlint = FlynnLint()
        flynnlint.process(output: output,
                          input: "\(packageRoot)/meta/fail")
        print("\(packageRoot)/Tests/sample")
        flynnlint.finish()
    }

    static var allTests = [
        ("testLocalDir", testLocalDir),
        ("testOneRuleOneCode", testOneRuleOneCode),
        ("testAllRulesOneCode", testAllRulesOneCode),
        ("testOneRule", testOneRule),
        ("testAllRules", testAllRules),
    ]
     */
}
