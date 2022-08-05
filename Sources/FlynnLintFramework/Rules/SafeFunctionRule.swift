//
//  main.swift
//  flynnlint
//
//  Created by Rocco Bowling on 5/29/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import Flynn
import SourceKittenFramework

struct SafeFunctionRule: Rule {

    let safeCallString = ".\(FlynnLint.prefixSafe)"
    let unsafeCallString = ".\(FlynnLint.prefixUnsafe)"

    let description = RuleDescription(
        identifier: "actors_safe_func",
        name: "Safe Access Violation",
        description: "Safe functions may not be called outside of the Actor.",
        syntaxTriggers: [.exprCall],
        nonTriggeringExamples: [
            Example("class SomeClass {}\n"),
            Example("class SomeActor: Actor {}\n"),
            Example("class SomeActor: Actor { private func foo() { } }\n"),
            Example("class SomeActor: Actor { init(_ data: OffToTheRacesData) { self.data = data } }\n"),
            Example("""
                class SomeActor: Actor {
                    func safeFoo() {
                        print("hello world")
                    }

                    override func safeFlowProcess() {
                        safeFoo()
                        self.safeFoo()
                    }
                }
            """)
        ],
        triggeringExamples: [
            Example("""
                class SomeActor: Actor {
                    func safeFoo() {
                        print("hello world")
                    }

                    override func safeFlowProcess() {
                        safeFoo()
                    }
                }
                let a = SomeActor()
                a.safeFlowProcess()
            """),
            Example("""
                func testCallSiteUncertainty() {
                    // https://github.com/KittyMac/flynn/issues/8

                    let actor = WhoseCallWasThisAnyway()

                    // Since calls to functions and calls to behaviors are visually similar,
                    // and we cannot enforce developers NOT to have non-private functions,
                    // someone reading this would think it would print a bunch of "foo"
                    // followed by a bunch of "bar".  Oh, they'd be so wrong.
                    actor.printFoo()
                    actor.printFoo()
                    actor.printFoo()
                    actor.printFoo()
                    actor.printFoo()
                    actor.printFoo()
                    actor.printFoo()
                    // TODO: flynnlint should flag these as errors
                    actor.safePrintBar()
                    actor.safePrintBar()
                    actor.safePrintBar()
                    actor.safePrintBar()
                    actor.safePrintBar()
                    actor.safePrintBar()
                    actor.safePrintBar()
                    actor.safePrintBar()

                    actor.wait(0)
                }
            """),
            Example("""
                open class Actor {
                    public func safeNextTarget() -> Actor? {
                        switch numTargets {
                        case 0:
                            return nil
                        case 1:
                            return flowTarget
                        default:
                            poolIdx = (poolIdx + 1) % numTargets
                            return flowTargets[poolIdx]
                        }
                    }
                }

                func testCallSiteUncertainty() {
                    // https://github.com/KittyMac/flynn/issues/8

                    let actor = WhoseCallWasThisAnyway()

                    // Since calls to functions and calls to behaviors are visually similar,
                    // and we cannot enforce developers NOT to have non-private functions,
                    // someone reading this would think it would print a bunch of "foo"
                    // followed by a bunch of "bar".  Oh, they'd be so wrong.
                    actor.printFoo()
                    actor.printFoo()
                    actor.printFoo()
                    actor.printFoo()
                    actor.printFoo()
                    actor.printFoo()
                    actor.printFoo()
                    actor.safeNextTarget()

                    actor.wait(0)
                }
            """)
        ]
    )

    func check(_ ast: AST, _ syntax: FileSyntax, _ output: Flowable?) -> Bool {
        // Only functions of the class may call safe methods on a class
        if let functionCall = syntax.structure.name {
            if  functionCall.range(of: safeCallString) != nil &&
                functionCall.hasPrefix("self.") == false {
                if let output = output {
                    output.beFlow([error(syntax.structure.offset, syntax)])
                }
                return false
            }
        }
        return true
    }

}
