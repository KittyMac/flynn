//
//  main.swift
//  flynnlint
//
//  Created by Rocco Bowling on 5/29/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// swiftlint:disable line_length
// swiftlint:disable cyclomatic_complexity
// swiftlint:disable function_body_length

import Foundation
import Flynn
import SourceKittenFramework

struct PrivateFunctionInRemoteActorRule: Rule {

    let description = RuleDescription(
        identifier: "remote_actors_private_func",
        name: "Access Level Violation",
        description: "Non-private functions are not allowed in RemoteActor; change to private, safe, or a behavior",
        syntaxTriggers: [.class, .extension],
        nonTriggeringExamples: [
            Example("class SomeClass {}\n"),
            Example("class SomeActor: RemoteActor {}\n"),
            Example("class SomeActor: RemoteActor { private func foo() { } }\n"),
            Example("class SomeActor: RemoteActor { override func safeFlowProcess() { } }\n"),
            Example("class SomeClass { public func foo() { } }\n"),

            Example("class SomeActor: RemoteActor { init() { var x = 5 } }\n"),

            Example("class SomeActor: RemoteActor { private func _bePrint(_ string: String) { } }\n"),

            Example("class SomeActor: RemoteActor { public func safeFoo() { } }\n"),
            Example("class SomeActor: RemoteActor { fileprivate func safeFoo() { } }\n"),
            Example("class SomeActor: RemoteActor { internal func safeFoo() { } }\n"),
            Example("class SomeActor: RemoteActor { func safeFoo() { } }\n"),
            Example("class SomeActor: RemoteActor { override func safeFlowProcess() { } }\n"),

            Example("""
                class SomeActor: RemoteActor {
                    public func bePrint() {
                        let serialized: [String: Codable] = ["foo" = "bar"]
                        self.unsafeSendToRemote(serialized)
                    }
                }
            """),
            Example("""
                public func bePrint(_ string: String) {
                    struct bePrintMessage: Codable {
                        let uuid: String
                        let type: String
                        let arg0: String
                    }
                    let msg = bePrintMessage(uuid: safeUUID, type: "Echo", arg0: string)
                    if let data = try? JSONEncoder().encode(msg) {
                        unsafeSend(data)
                    }else{
                        fatalError("Echo.bePrint() arguments failed to serialize")
                    }
                }
            """)
        ],
        triggeringExamples: [
            Example("class SomeActor: RemoteActor { init(_ data: OffToTheRacesData) { self.data = data } }\n"),

            Example("class SomeActor: RemoteActor { public func _bePrint(_ string: String) { } }\n"),
            Example("class SomeActor: RemoteActor { fileprivate func _bePrint(_ string: String) { } }\n"),
            Example("class RemoteActor { public func unsafeSend() { } }\n"),

            Example("class SomeActor: RemoteActor { public func foo() { } }\n"),
            Example("class SomeActor: RemoteActor { fileprivate func foo() { } }\n"),
            Example("class SomeActor: RemoteActor { internal func foo() { } }\n"),
            Example("class SomeActor: RemoteActor { func foo() { } }\n"),
            Example("class SomeActor: RemoteActor { override func flowProcess() { } }\n"),
            Example("""
                public protocol Viewable: RemoteActor {
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

    func check(_ ast: AST, _ syntax: FileSyntax, _ output: Flowable?) -> Bool {
        // Every function defined in a class which is a subclass of Actor must follow these rules:
        // 1. its access control level (ACL) must be set to private
        // 2. if it starts with safe, its ACL may be anything. Other rules will keep anything
        //    but a subclass of this Actor calling safe methods
        // 3. if it is an init function

        var allPassed = true

        if let resolvedClass = ast.getClassOrProtocol(syntax.structure.name) {
            if ast.isRemoteActor(resolvedClass) {
                if let functions = syntax.structure.substructure {
                    for function in functions {
                        if (function.name ?? "").hasPrefix(FlynnLint.prefixBehaviorExternal) &&
                            function.kind == .functionMethodInstance {
                            // This might be an external behavior; if it is, then the body should
                            // contain an unsafeSend(). We have other rules in place to ensure that
                            // this compliance is in place, so for here we just need to exempt it

                            if syntax.match(#"unsafeSendToRemote\s*\("#) == nil {
                                if let output = output {
                                    output.beFlow([error(function.offset, syntax, description.console("Behaviors must call unsafeSendToRemote()"))])
                                }
                                allPassed = false
                            }
                            continue
                        }

                        if !(function.name ?? "").hasPrefix(FlynnLint.prefixUnsafe) &&
                            !(function.name ?? "").hasPrefix(FlynnLint.prefixSafe) &&
                            !(function.name ?? "").hasPrefix(FlynnLint.prefixBehaviorInternal) &&
                            !(function.name ?? "").hasPrefix("init") &&
                            !(function.name ?? "").hasPrefix("deinit") &&
                            function.kind == .functionMethodInstance &&
                            function.accessibility != .private {
                            if let output = output {
                                output.beFlow([error(function.offset, syntax)])
                            }
                            allPassed = false
                            continue
                        }

                        if (function.name ?? "").hasPrefix(FlynnLint.prefixBehaviorInternal) &&
                            function.kind == .functionMethodInstance &&
                            function.accessibility != .private {
                            if let output = output {
                                output.beFlow([error(function.offset, syntax, description.console("Behaviors must be private"))])
                            }
                            allPassed = false
                            continue
                        }

                        if (function.name ?? "").hasPrefix(FlynnLint.prefixUnsafe) &&
                            !(function.name ?? "").hasPrefix("unsafeSendToRemote(") &&
                            !(function.name ?? "").hasPrefix("unsafeExecuteBehavior(") &&
                            !(function.name ?? "").hasPrefix("unsafeIsConnected(") &&
                            !(function.name ?? "").hasPrefix("unsafeHandleBehaviorReply(") &&
                            !(function.name ?? "").hasPrefix("unsafeRegisterAllBehaviors(") &&
                            function.kind == .functionMethodInstance &&
                            function.accessibility != .private {
                            if let output = output {
                                output.beFlow([error(function.offset, syntax, description.console("Unsafe functions are not allowed on remote actors"))])
                            }
                            allPassed = false
                            continue
                        }

                        if (function.name ?? "").hasPrefix("init") &&
                            function.kind == .functionMethodInstance {
                            let (_, parameterLabels) = ast.parseFunctionDefinition(function)
                            if parameterLabels.count > 0 {
                                if let output = output {
                                    output.beFlow([error(function.offset, syntax, description.console("Initializers with parameters are not allowed on remote actors"))])
                                }
                                allPassed = false
                                continue
                            }
                        }

                    }
                }
            }
        }

        return allPassed
    }

}
