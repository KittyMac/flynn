//
//  main.swift
//  flynnlint
//
//  Created by Rocco Bowling on 5/29/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import Flynn
import SourceKittenFramework

struct Ruleset {
    var all: [Rule] = []
    var byKind: [SwiftDeclarationKind: [Rule]] = [:]

    init() {
        let allRules: [Rule.Type] = [
            PrivateFunctionInActorRule.self,
            SafeFunctionRule.self,
            PrivateVariablesInActorRule.self,
            SafeVariableRule.self,
            PrivateFunctionInRemoteActorRule.self,
            PrivateVariablesInRemoteActorRule.self
        ]

        for ruleClass in allRules {
            let rule = ruleClass.init()

            all.append(rule)

            for trigger in rule.description.syntaxTriggers {
                if self.byKind[trigger] == nil {
                    self.byKind[trigger] = []
                }
                self.byKind[trigger]?.append(rule)
            }
        }
    }
}

protocol Rule {

    init()

    var description: RuleDescription { get }

    func precheck(_ file: File) -> Bool

    @discardableResult
    func check(_ ast: AST, _ syntax: FileSyntax, _ output: Flowable?) -> Bool
}

extension Rule {

    func precheck(_ file: File) -> Bool {
        return true
    }

    func error(_ offset: Int64?, _ fileSyntax: FileSyntax, _ msg: String) -> String {
        let path = fileSyntax.file.path ?? "<nopath>"
        if let offset = offset {
            let stringView = StringView.init(fileSyntax.file.contents)
            if let (line, character) = stringView.lineAndCharacter(forByteOffset: ByteCount(offset)) {
                return "\(path):\(line):\(character): error: \(msg)"
            }
        }
        return "\(path): error: \(msg)"
    }

    func error(_ offset: Int64?, _ fileSyntax: FileSyntax) -> String {
        return error(offset, fileSyntax, description.consoleDescription)
    }

    func warning(_ offset: Int64?, _ fileSyntax: FileSyntax, _ msg: String) -> String {
        let path = fileSyntax.file.path ?? "<nopath>"
        if let offset = offset {
            let stringView = StringView.init(fileSyntax.file.contents)
            if let (line, character) = stringView.lineAndCharacter(forByteOffset: ByteCount(offset)) {
                return "\(path):\(line):\(character): warning: \(msg)"
            }
        }
        return "\(path): warning: \(msg)"
    }

    func warning(_ offset: Int64?, _ fileSyntax: FileSyntax) -> String {
        return warning(offset, fileSyntax, description.consoleDescription)
    }

    func test(_ code: String) -> Bool {
        let printError: PrintError? = PrintError()
        //let printError: PrintError? = nil

        do {
            let file = File(contents: code)
            let syntax = try StructureAndSyntax(file: file)
            let fileSyntax = FileSyntax("/tmp",
                                        file,
                                        syntax.structure,
                                        [],
                                        syntax.syntax,
                                        [])

            let astBuilder = ASTBuilder()
            astBuilder.add(fileSyntax)

            let ast = astBuilder.build()

            for syntax in astBuilder {

                if description.syntaxTriggers.count == 0 {
                    if !check(ast, syntax, printError) {
                        return false
                    }
                } else if description.syntaxTriggers.contains(syntax.structure.kind!) {
                    if !check(ast, syntax, printError) {
                        return false
                    }
                }
            }

        } catch {
            print("Parsing error: \(error)")
        }
        return true
    }

    func test() -> Bool {
        for example in description.nonTriggeringExamples {
            if test(example) != true {
                print("\(description.identifier) failed on nonTriggeringExample:\n\(example)")
                return false
            }
        }
        for example in description.triggeringExamples {
            if test(example) != false {
                print("\(description.identifier) failed on triggeringExamples:\n\(example)")
                return false
            }
        }
        return true
    }

}
