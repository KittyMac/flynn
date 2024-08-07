import Foundation
import SourceKittenFramework

struct SafeVariableRule: Rule {
    let description = RuleDescription(
        identifier: "actors_safe_var",
        name: "Safe Access Violation",
        description: "Safe variables may not be called outside of the Actor.",
        syntaxTriggers: [ ],
        nonTriggeringExamples: [
            Example("""
                class SomeActor: Actor {
                    var safeColorable = 5
                }
                class OtherActor: SomeActor {
                    func foo() {
                        safeColorable = 15
                        self.safeColorable = 15
                    }
                }
            """),
            Example("""
                func testColor() {
                    let expectation = XCTestExpectation(description: "Protocols, extensions etc...")
                    let color = Color()
                    color.render(CGRect.zero)
                    //print(color.safeColorable._color)
                    /* print(color.safeColorable._color) */
                    /*
                     * print(color.safeColorable._color)
                     */
                    ///print(color.safeColorable._color)
                    expectation.fulfill()
                }
            """),
            Example("""
                func testArrayOfColors() {
                    let expectation = XCTestExpectation(description: "Array of actors by protocol")
                    let views: [Viewable] = Array(count: Flynn.cores) { Color() }
                    for view in views {
                        view.render(CGRect.zero)
                    }
                    expectation.fulfill()
                }
            """)
        ],
        triggeringExamples: [
            Example("""
                class SomeActor: Actor {
                    var safeColorable = 5
                }
                class OtherActor: SomeActor {
                    func foo() {
                        let a = SomeActor()
                        a.safeColorable = 15
                    }
                }
            """),
            Example("""
                func testColor() {
                    let expectation = XCTestExpectation(description: "Protocols, extensions etc...")
                    let color = Color()
                    color.render(CGRect.zero)
                    print(color.safeColorable._color)
                    expectation.fulfill()
                }
            """)
        ]
    )
    
    func precheck(_ file: File) -> Bool {
        guard file.contents.contains("// flynn:ignore all") == false else { return false }
        guard file.contents.contains("// flynn:ignore \(description.name)") == false else { return false }
        return file.contents.contains(".\(FlynnPluginTool.prefixSafe)")
    }

    func check(_ ast: AST, _ syntax: FileSyntax, _ output: inout [PrintError.Packet]) -> Bool {
        // sourcekit doesn't give us structures for variable accesses. So the
        // best we can do is grep the body contents. Doing this, we are looking
        // or any instances of .safe which are not self.safe This is
        // FAR from perfect, but until sourcekit provides the full, unadultered
        // AST what can we do?
        if let innerOffset = syntax.match(#"\w+(?<!self)\."# + FlynnPluginTool.prefixSafe + #"\w"#) {
            output.append(error(innerOffset, syntax))
            return false
        }

        return true
    }

}
