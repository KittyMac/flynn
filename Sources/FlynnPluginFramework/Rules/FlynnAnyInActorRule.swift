import Foundation
import SourceKittenFramework

struct FlynnAnyInActorRule: Rule {

    let description = RuleDescription(
        identifier: "actors_flynn_any",
        name: "Flynn.Any Warning",
        description: "Flynn.any inside of an Actor; did you mean to use self?",
        syntaxTriggers: [.exprCall],
        nonTriggeringExamples: [
            Example("""
                class WhoseCallWasThisAnyway: Actor {
                    internal func _beCheckScript() {
                        ScriptManager.shared.beGet(self) {
                            print("HERE")
                        }
                    }
                }
            """),
            Example("""
                class WhoseCallWasThisAnyway {
                    internal func something() {
                        ScriptManager.shared.beGet(Flynn.any) { }
                    }
                }
            """)
        ],
        triggeringExamples: [
            Example("""
                class WhoseCallWasThisAnyway: Actor {
                    internal func _beCheckScript() {
                        ScriptManager.shared.beGet(Flynn.any) { }
                    }
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
        
        var isActorOrRemoteActor = false
        for ancestor in syntax.ancestry {
            if ast.isActor(ancestor) || ast.isRemoteActor(ancestor) {
                isActorOrRemoteActor = true
                break
            }
        }
        
        guard isActorOrRemoteActor else { return true }
        
        var errorOffsets: [Int64] = []
        // Only perform this check if we are inside of an Actor
        syntax.matches(#"Flynn.any"#) { offset, match, groups in
            errorOffsets.append(offset)
        }
        errorOffsets.forEach {
            output.append(warning($0, syntax))
        }
        return errorOffsets.count == 0
    }
}
