import Foundation
import SourceKittenFramework

struct DoNotPrecededByThenCall: Rule {

    let description = RuleDescription(
        identifier: "do_not_preceded_by_then",
        name: "Then/Do Violation",
        description: ".do() behaviour must immediately preceded by a .then()",
        syntaxTriggers: [.exprCall],
        nonTriggeringExamples: [
            Example("Actor().beCall { }.then().doCall()\n"),
        ],
        triggeringExamples: [
            Example("Actor().beCall().then().doCall()\n"),
            Example("Actor().then().doCall();\n"),
            Example("ThenActor().doFourth().then().doNothing()\n")
        ]
    )

    func check(_ ast: AST, _ syntax: FileSyntax, _ output: inout [PrintError.Packet]) -> Bool {
        guard syntax.markup("ignore all", unbounded: true).isEmpty else { return true }
        guard syntax.markup("ignore \(description.name)", unbounded: true).isEmpty else { return true }
        
        var errorOffsets: [Int64] = []
        
        // Check for then() which is not followed by a doCall()
        syntax.matches(#"[^}\s](?:\s*\.then\()"#) { offset, match, groups in
            errorOffsets.append(offset)
        }
        errorOffsets.forEach {
            output.append(error($0, syntax))
        }
        return errorOffsets.count == 0
    }

}
