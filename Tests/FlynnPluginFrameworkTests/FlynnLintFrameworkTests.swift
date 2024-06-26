//
//  FlynnPluginTests.swift
//  FlynnPluginTests
//
//  Created by Rocco Bowling on 5/31/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

#if os(Windows)
public let flynnTempPath = "C:/WINDOWS/Temp/"
#else
public let flynnTempPath = "/tmp/"
#endif

import XCTest
@testable import FlynnPluginFramework

class FlynnPluginTests: XCTestCase {
    var output = "\(flynnTempPath)/FlynnPlugin"
    var packageRoot = ""
    
    override func setUpWithError() throws {
        packageRoot = #file.replacingOccurrences(of: "/Tests/FlynnPluginFrameworkTests/FlynnPluginFrameworkTests.swift", with: "")
    }

    override func tearDownWithError() throws { }
    
    func testExample() throws {
        let flynnplugin = FlynnPluginTool()
        flynnplugin.process(input: "/Users/rjbowli/Development/chimerasw/Flynn/Examples/HelloWorld/Sources/HelloWorld/main.swift",
                            output: "\(flynnTempPath)/FlynnPlugin.swift")
    }
    
    func testFlynn() throws {
        
        let flynnplugin = FlynnPluginTool()
        
        let files = [
            "/Users/rjbowli/Development/chimerasw/Flynn/Sources/Flynn/Flowable.swift",
            "/Users/rjbowli/Development/chimerasw/Flynn/Sources/Flynn/Flynn+Timer.swift",
            "/Users/rjbowli/Development/chimerasw/Flynn/Sources/Flynn/Atomics.swift",
            "/Users/rjbowli/Development/chimerasw/Flynn/Sources/Flynn/Flynn.swift",
            "/Users/rjbowli/Development/chimerasw/Flynn/Sources/Flynn/Extensions.swift",
            "/Users/rjbowli/Development/chimerasw/Flynn/Sources/Flynn/Queue.swift",
            "/Users/rjbowli/Development/chimerasw/Flynn/Sources/Flynn/Actor.swift",
            "/Users/rjbowli/Development/chimerasw/Flynn/Sources/Flynn/Remote/Flynn+Remote.swift",
            "/Users/rjbowli/Development/chimerasw/Flynn/Sources/Flynn/Remote/RemoteActorManager.swift",
            "/Users/rjbowli/Development/chimerasw/Flynn/Sources/Flynn/Remote/RemoteActorRunner.swift",
            "/Users/rjbowli/Development/chimerasw/Flynn/Sources/Flynn/Remote/RemoteActor.swift",
            "/Users/rjbowli/Development/chimerasw/Flynn/Tests/FlynnTests/Support/WeakTimer.swift"
        ]
        
        flynnplugin.process(inputs: files,
                            output: "\(flynnTempPath)/FlynnPlugin.swift")
        
        
    }
    /*
    func testFlynn2() throws {
        let flynnplugin = FlynnPluginTool()
        flynnplugin.process(input: "/Users/rjbowli/Library/Developer/Xcode/DerivedData/Flynn-atlbddvexwtcxmbjhpgyyonyzrrj/SourcePackages/flynn/FlynnTests/FlynnPlugin/inputFiles.txt",
                            output: "\(flynnTempPath)/FlynnPlugin.swift")
    }
    
    func testFlynn3() throws {
        let flynnplugin = FlynnPluginTool()
        flynnplugin.process(input: "/Users/rjbowli/Development/chimerasw/Picaroon/.build/plugins/outputs/picaroon/Picaroon/FlynnPlugin/inputFiles.txt",
                            output: "\(flynnTempPath)/FlynnPlugin.swift")
    }
    
    func testFlynn4() throws {
        let flynnplugin = FlynnPluginTool()
        flynnplugin.process(input: "/Users/rjbowli/Development/smallplanet/npd_ReceiptPal_iOS/receiptpal_amazon/swift/ErrorLogServer/.build/plugins/outputs/errorlogserver/ErrorLogServerFramework/FlynnPlugin/inputFiles.txt",
                            output: "\(flynnTempPath)/FlynnPlugin.swift")
    }
    */
    
    #if DEBUG

    func testOneRuleOneCode() throws {
        /*
        let rule = DoNotPrecededByThenCall()
        XCTAssert(rule.test("""
            ThenActor().then().doFourth().then().doNothing()
        """))
         */
    }
    
    func testAllRulesOneCode() throws {
        let code = """
            class TestActor: Actor {
                private var string: String = ""

                internal func _bePrint() {
                    print("Hello world")
                }
            }
        """
        let rules = Ruleset()
        for rule in rules.all {
            let result = rule.test(code)
            if result == false {
                print("failed rule: \(rule)")
            }
            XCTAssert(result)
        }
    }

    func testOneRule() throws {
        let rule = FlynnAnyInActorRule()
        XCTAssert(rule.test())
    }

    func testAllRules() throws {
        let rules = Ruleset()
        for rule in rules.all {
            XCTAssert(rule.test())
        }
    }
    
    #endif
}
