import Foundation
import SourceKittenFramework

struct PrivateFunctionInActorRule: Rule {

    let description = RuleDescription(
        identifier: "actors_private_func",
        name: "Access Level Violation",
        description: "Non-private functions are not allowed in Actors; change to private, safe/unsafe, or a behavior",
        syntaxTriggers: [.class, .extension],
        nonTriggeringExamples: [
            Example("class SomeClass {}\n"),
            Example("class SomeActor: Actor {}\n"),
            Example("class SomeActor: Actor { private func foo() { } }\n"),
            Example("class SomeActor: Actor { init(_ data: OffToTheRacesData) { self.data = data } }\n"),
            Example("class SomeActor: Actor { override func safeFlowProcess() { } }\n"),
            Example("class SomeClass { public func foo() { } }\n"),

            Example("class SomeActor: Actor { internal func _bePrint(_ string: String) { } }\n"),

            Example("class SomeActor: Actor { public func unsafeFoo() { } }\n"),
            Example("class SomeActor: Actor { fileprivate func unsafeFoo() { } }\n"),
            Example("class SomeActor: Actor { internal func unsafeFoo() { } }\n"),
            Example("class SomeActor: Actor { func unsafeFoo() { } }\n"),
            Example("class SomeActor: Actor { override func unsafeFlowProcess() { } }\n")
        ],
        triggeringExamples: [

            Example("class SomeActor: Actor { public func _bePrint(_ string: String) { } }\n"),
            Example("class SomeActor: Actor { fileprivate func _bePrint(_ string: String) { } }\n"),

            Example("class SomeActor: Actor { public func foo() { } }\n"),
            Example("class SomeActor: Actor { fileprivate func foo() { } }\n"),
            Example("class SomeActor: Actor { internal func foo() { } }\n"),
            Example("class SomeActor: Actor { func foo() { } }\n"),
            Example("class SomeActor: Actor { override func flowProcess() { } }\n"),
            Example("""
                public protocol Viewable: Actor {
                    var beRender: Behavior { get }
                }

                public extension Viewable {

                    func viewableSubmitRenderUnit(_ ctx: RenderFrameContext,
                                                  _ vertices: FloatAlignedArray,
                                                  _ contentSize: GLKVector2,
                                                  _ shaderType: ShaderType = .flat,
                                                  _ textureName: String? = nil,
                                                  _ partNumber: Int64 = 0) {
                        let unit = RenderUnit(ctx,
                                              shaderType,
                                              vertices,
                                              contentSize,
                                              partNumber,
                                              textureName)
                        ctx.renderer.beSubmitRenderUnit(ctx, unit)
                    }

                    func safeViewableSubmitRenderFinished(_ ctx: RenderFrameContext) {
                        ctx.renderer.beSubmitRenderFinished(ctx)
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
        
        // Every function defined in a class which is a subclass of Actor must follow these rules:
        // 1. its access control level (ACL) must be set to private
        // 2. if it starts with safe, its ACL may be anything. Other rules will keep anything
        //    but a subclass of this Actor calling safe methods
        // 3. if it is an init function

        var allPassed = true

        if let resolvedClass = ast.getClassOrProtocol(syntax.structure.name) {
            if ast.isActor(resolvedClass) {
                if let functions = syntax.structure.substructure {
                    for function in functions {
                        if (function.name ?? "").hasPrefix(FlynnPluginTool.prefixBehaviorExternal) &&
                            function.kind == .functionMethodInstance {
                            // This might be an external behavior; if it is, then the body should
                            // start with unsafeSend(). We have other rules in place to ensure that
                            // this compliance is in place, so for here we just need to exempt it

                            if let substructures = function.substructure {

                                // must contain only parameters and one unsafe send
                                var numParameters = 0
                                var numUnsafeSend = 0
                                var numOther = 0

                                for substructure in substructures {
                                    if substructure.kind == .exprCall &&
                                        (substructure.name == "unsafeSend" || substructure.name == "self.unsafeSend") {
                                        numUnsafeSend += 1
                                    } else if substructure.kind == .varParameter {
                                        numParameters += 1
                                    } else {
                                        numOther += 1
                                    }
                                }

                                if !(numUnsafeSend == 1 && numOther == 0) {
                                    output.append(error(function.offset, syntax, description.console("Behaviors must wrap their contents in a call to unsafeSend()")))
                                    allPassed = false
                                }
                            }
                            continue
                        }

                        if !(function.name ?? "").hasPrefix(FlynnPluginTool.prefixUnsafe) &&
                            !(function.name ?? "").hasPrefix(FlynnPluginTool.prefixSafe) &&
                            !(function.name ?? "").hasPrefix(FlynnPluginTool.prefixBehaviorInternal) &&
                            !(function.name ?? "").hasPrefix("then(") &&
                            !(function.name ?? "").hasPrefix("init(") &&
                            !(function.name ?? "").hasPrefix("deinit") &&
                            !(function.name ?? "").hasPrefix("hash(into") &&
                            function.kind == .functionMethodInstance &&
                            function.accessibility != .private {
                            output.append(error(function.offset, syntax))
                            allPassed = false
                            continue
                        }

                        if (function.name ?? "").hasPrefix(FlynnPluginTool.prefixBehaviorInternal) &&
                            function.kind == .functionMethodInstance &&
                            function.accessibility != .internal {
                            output.append(error(function.offset, syntax, description.console("Behaviours must be internal")))
                            allPassed = false
                            continue
                        }

                        if (function.name ?? "").hasPrefix(FlynnPluginTool.prefixUnsafe) &&
                            function.kind == .functionMethodInstance &&
                            function.accessibility != .private {
                            output.append(warning(function.offset, syntax, description.console("Unsafe functions should not be used")))
                            continue
                        }

                    }
                }
            }
        }

        return allPassed
    }

}
