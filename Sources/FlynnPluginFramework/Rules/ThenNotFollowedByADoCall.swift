import Foundation
import SourceKittenFramework

struct ThenNotFollowedByADoCall: Rule {

    let description = RuleDescription(
        identifier: "then_not_followed_by_do",
        name: "Then/Do Violation",
        description: ".then() must immediately be followed by a .do() behaviour call",
        syntaxTriggers: [.exprCall],
        nonTriggeringExamples: [
            Example("Actor().beCall { }.then().doCall()\n"),
        ],
        triggeringExamples: [
            Example("Actor().beCall { }.then().beCall()\n"),
            Example("Actor().beCall { }.then(); print();\n"),
            Example("Actor().beCall { }.then()\n")
        ]
    )

    func check(_ ast: AST, _ syntax: FileSyntax, _ output: inout [PrintError.Packet]) -> Bool {
        guard syntax.markup("ignore all", unbounded: true).isEmpty else { return true }
        guard syntax.markup("ignore \(description.name)", unbounded: true).isEmpty else { return true }

        var errorOffsets: [Int64] = []
        
        // Check for then() which is not followed by a doCall()
        syntax.matches(#"then[\s\n\r\t]*\([\s\n\r\t]*\)(?![\s\n\r\t]*\.do[A-Z])"#) { offset, match, groups in
            errorOffsets.append(offset)
        }
        errorOffsets.forEach {
            output.append(error($0, syntax))
        }
        return errorOffsets.count == 0
    }

}
