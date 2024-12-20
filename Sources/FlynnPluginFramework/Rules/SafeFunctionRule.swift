import Foundation
import SourceKittenFramework

struct SafeFunctionRule: Rule {

    let safeCallString = ".\(FlynnPluginTool.prefixSafe)"
    let unsafeCallString = ".\(FlynnPluginTool.prefixUnsafe)"
    
    let selfSafeCallString = "self.\(FlynnPluginTool.prefixSafe)"

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

    func precheck(_ file: File) -> Bool {
        guard file.contents.contains("// flynn:ignore all") == false else { return false }
        guard file.contents.contains("// flynn:ignore \(description.name)") == false else { return false }
        return true
    }
    
    func check(_ ast: AST, _ syntax: FileSyntax, _ output: inout [PrintError.Packet]) -> Bool {
        // Only functions of the class may call safe methods on a class
        if let functionCall = syntax.structure.name {
            if  functionCall.range(of: safeCallString) != nil &&
                functionCall.range(of: selfSafeCallString) == nil {
                output.append(error(syntax.structure.offset, syntax))
                return false
            }
        }
        return true
    }

}
