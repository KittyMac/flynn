import Foundation
import SourceKittenFramework

struct WeakTimersRule: Rule {

    let description = RuleDescription(
        identifier: "weak_timer_callback",
        name: "Weak Timer Violation",
        description: "Flynn.Timer callbacks must use [weak self]",
        syntaxTriggers: [.exprCall],
        nonTriggeringExamples: [
            Example("class SomeClass {}\n"),
            Example("class SomeActor: Actor {}\n"),
            Example("class SomeActor: Actor { private func foo() { } }\n"),
            Example("class SomeActor: Actor { init(_ data: OffToTheRacesData) { self.data = data } }\n"),
            Example("""
                class SomeActor: Actor {
                    func safeFoo() {
                        timer = Flynn.Timer(timeInterval: 1, repeats: true, self) { [weak self] _ in
                            print("timer count")
                            count += 1
                        }
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
                        timer = Flynn.Timer(timeInterval: 1, repeats: true, self) { _ in
                            print("timer count")
                            count += 1
                        }
                    }

                    override func safeFlowProcess() {
                        safeFoo()
                    }
                }
                let a = SomeActor()
                a.safeFlowProcess()
            """)
        ]
    )

    func check(_ ast: AST, _ syntax: FileSyntax, _ output: inout [PrintError.Packet]) -> Bool {
        guard syntax.file.contents.contains("WeakTimer -> deinit") else { return true }
        
        var errorOffsets: [Int64] = []
        syntax.matches(#"Flynn.Timer\([^\)]*\)[^{]*\{(.*)in"#) { offset, match, groups in
            if groups[1].contains("[weak self]") == false && groups[1].contains("[unowned self]") == false {
                errorOffsets.append(offset)
            }
        }
        errorOffsets.forEach {
            output.append(error($0, syntax))
        }
        return errorOffsets.count == 0
    }

}
