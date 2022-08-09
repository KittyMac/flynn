import Foundation
import SourceKittenFramework

class CheckRules {
    // input: an AST and one syntax structure
    // output: error string if rule failed
    
    private let rules: Ruleset

    init(_ rules: Ruleset) {
        self.rules = rules
    }

    func process(packets: [AutogenerateExternalBehaviors.Packet]) -> [PrintError.Packet] {
        var next: [PrintError.Packet] = []
        
        for packet in packets {
            let ast: AST = packet.ast
            let syntax: FileSyntax = packet.syntax
            let fileOnly: Bool = packet.fileOnly

            let blacklist = syntax.blacklist

            if fileOnly {
                for rule in self.rules.all where !blacklist.contains(rule.description.identifier) {
                    rule.check(ast, syntax, &next)
                }
            } else {
                if let kind = syntax.structure.kind {
                    if let rules = self.rules.byKind[kind] {
                        for rule in rules where !blacklist.contains(rule.description.identifier) {
                            rule.check(ast, syntax, &next)
                        }
                    }
                }
            }
        }

        return next
    }
    
}
