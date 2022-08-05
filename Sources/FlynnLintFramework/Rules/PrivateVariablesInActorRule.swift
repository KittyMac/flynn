//
//  main.swift
//  flynnlint
//
//  Created by Rocco Bowling on 5/29/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// swiftlint:disable line_length
// swiftlint:disable cyclomatic_complexity

import Foundation
import Flynn
import SourceKittenFramework

struct PrivateVariablesInActorRule: Rule {

    let description = RuleDescription(
        identifier: "actors_private_vars",
        name: "Access Level Violation",
        description: "Non-private variables are not allowed in Actors; change to private or safe/unsafe",
        syntaxTriggers: [.class, .extension],
        nonTriggeringExamples: [
            Example("class SomeClass {}\n"),
            Example("class SomeActor: Actor { private var x:Int = 0 }\n"),
            Example("class SomeActor: Actor { private let x:Int = 0 }\n"),
            Example("""
                class WhoseCallWasThisAnyway: Actor {
                    lazy var printFoo = ChainableBehavior(self) { (_: BehaviorArgs) in
                        print("foo")
                    }
                }
            """),
            Example("""
                class WhoseCallWasThisAnyway: Actor {
                    public lazy var safeColorable = "hello"
                }
            """),

            Example("class SomeActor: Actor { var unsafeX:Int = 0 }\n"),
            Example("class SomeActor: Actor { let unsafeX:Int = 0 }\n"),
            Example("""
                class WhoseCallWasThisAnyway: Actor {
                    public lazy var unsafeColorable = "hello"
                }
            """)
        ],
        triggeringExamples: [
            Example("class SomeActor: Actor { var x:Int = 0 }\n"),
            Example("class SomeActor: Actor { let x:Int = 0 }\n"),
            Example("""
                class WhoseCallWasThisAnyway: Actor {
                    public lazy var _colorable = "hello"
                }
            """)
        ]
    )

    func check(_ ast: AST, _ syntax: FileSyntax, _ output: Flowable?) -> Bool {
        var allPassed = true

        if let resolvedClass = ast.getClassOrProtocol(syntax.structure.name) {
            if ast.isActor(resolvedClass) {
                if let variables = syntax.structure.substructure {

                    for idx in 0..<variables.count {
                        let variable = variables[idx]
                        if (variable.kind == .varGlobal || variable.kind == .varClass || variable.kind == .varInstance) &&
                            variable.accessibility != .private {

                            // If we're a Behavior or ChainableBehavior, then this is Ok. To know this, we need the sibling
                            // structure of this structure
                            if let typename = variable.typename {
                                if typename.contains("Behavior") {
                                    continue
                                }
                            }
                            if idx+1 < variables.count {
                                let sibling = variables[idx+1]
                                if let name = sibling.name {
                                    if name.contains("Behavior") && sibling.kind == .exprCall {
                                        continue
                                    }
                                }
                            }

                            if let name = variable.name {
                                // allow variables to be "safe"
                                if name.hasPrefix(FlynnLint.prefixSafe) {
                                    continue
                                }
                                // allow variables to be "unsafe"
                                if name.hasPrefix(FlynnLint.prefixUnsafe) {
                                    if let output = output {
                                        output.beFlow([warning(variable.offset, syntax, description.console("Unsafe variables should not be used"))])
                                    }
                                    continue
                                }
                            }

                            if let output = output {
                                output.beFlow([error(variable.offset, syntax)])
                            }
                            allPassed = false
                        }
                    }
                }
            }
        }
        return allPassed
    }
}
