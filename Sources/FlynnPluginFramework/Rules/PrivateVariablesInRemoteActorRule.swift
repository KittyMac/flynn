import Foundation
import SourceKittenFramework

struct PrivateVariablesInRemoteActorRule: Rule {

    let description = RuleDescription(
        identifier: "remote_actors_private_vars",
        name: "Access Level Violation",
        description: "Non-private variables are not allowed in RemoteActor; change to private or safe",
        syntaxTriggers: [.class, .extension],
        nonTriggeringExamples: [
            Example("class SomeClass {}\n"),
            Example("class SomeActor: RemoteActor { private var x:Int = 0 }\n"),
            Example("class SomeActor: RemoteActor { private let x:Int = 0 }\n"),
            Example("""
                class WhoseCallWasThisAnyway: RemoteActor {
                    lazy var printFoo = ChainableBehavior(self) { (_: BehaviorArgs) in
                        print("foo")
                    }
                }
            """),
            Example("""
                class WhoseCallWasThisAnyway: RemoteActor {
                    public lazy var safeColorable = "hello"
                }
            """)
        ],
        triggeringExamples: [
            Example("class SomeActor: RemoteActor { var x:Int = 0 }\n"),
            Example("class SomeActor: RemoteActor { let x:Int = 0 }\n"),
            Example("""
                class WhoseCallWasThisAnyway: RemoteActor {
                    public lazy var _colorable = "hello"
                }
            """),
            Example("class SomeActor: RemoteActor { var unsafeX:Int = 0 }\n"),
            Example("class SomeActor: RemoteActor { let unsafeX:Int = 0 }\n"),
            Example("""
                class WhoseCallWasThisAnyway: RemoteActor {
                    public lazy var unsafeColorable = "hello"
                }
            """)
        ]
    )

    func check(_ ast: AST, _ syntax: FileSyntax, _ output: inout [PrintError.Packet]) -> Bool {
        guard syntax.markup("ignoreall", unbounded: true).isEmpty else { return true }
        
        var allPassed = true

        if let resolvedClass = ast.getClassOrProtocol(syntax.structure.name) {
            if ast.isRemoteActor(resolvedClass) {
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
                                if name.hasPrefix(FlynnPluginTool.prefixSafe) {
                                    continue
                                }
                                // disallow variables to be "unsafe"
                                if name.hasPrefix(FlynnPluginTool.prefixUnsafe) {

                                    // For RemoteActor, access to its uuid needs to be allowed.
                                    if name == "unsafeUUID" {
                                        continue
                                    }

                                    output.append(error(variable.offset, syntax, description.console("Unsafe variables are not allowed in RemoteActor")))
                                    allPassed = false
                                    continue
                                }
                            }

                            output.append(error(variable.offset, syntax))
                            allPassed = false
                        }
                    }
                }
            }
        }
        return allPassed
    }
}
