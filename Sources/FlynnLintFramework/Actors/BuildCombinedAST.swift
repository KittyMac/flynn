//
//  main.swift
//  flynnlint
//
//  Created by Rocco Bowling on 5/29/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import SourceKittenFramework
import Flynn

// swiftlint:disable line_length
// swiftlint:disable cyclomatic_complexity

extension String {
    func substring(with nsrange: NSRange) -> Substring? {
        guard let range = Range(nsrange, in: self) else { return nil }
        return self[range]
    }
    
    func matches(_ regex: NSRegularExpression, _ callback: @escaping ((NSTextCheckingResult, [String]) -> Void)) {
        let body = self
        let nsrange = NSRange(location: Int(0), length: Int(count))
        regex.enumerateMatches(in: body, options: [], range: nsrange) { (match, _, _) in
            guard let match = match else { return }

            var groups: [String] = []
            for iii in 0..<match.numberOfRanges {
                if let groupString = body.substring(with: match.range(at: iii)) {
                    groups.append(String(groupString))
                }
            }
            callback(match, groups)
        }
    }

    func matches(_ pattern: String, _ callback: @escaping ((NSTextCheckingResult, [String]) -> Void)) {
        do {
            let body = self
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsrange = NSRange(location: Int(0), length: Int(count))
            regex.enumerateMatches(in: body, options: [], range: nsrange) { (match, _, _) in
                guard let match = match else { return }

                var groups: [String] = []
                for iii in 0..<match.numberOfRanges {
                    if let groupString = body.substring(with: match.range(at: iii)) {
                        groups.append(String(groupString))
                    }
                }
                callback(match, groups)
            }
        } catch { }
    }

    func deletingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }

    func deletingSuffix(_ suffix: String) -> String {
        guard self.hasSuffix(suffix) else { return self }
        return String(self.dropLast(suffix.count))
    }
}

struct FileSyntax {
    let outputPath: String
    let file: File
    let structure: SyntaxStructure
    let ancestry: [FileSyntax]
    let tokens: [SyntaxToken]
    let blacklist: [String]

    init(_ outputPath: String,
         _ file: File,
         _ structure: SyntaxStructure,
         _ ancestry: [FileSyntax],
         _ tokens: [SyntaxToken],
         _ blacklist: [String]) {
        self.outputPath = outputPath
        self.file = file
        self.structure = structure
        self.tokens = tokens
        self.blacklist = blacklist
        self.ancestry = ancestry
    }
    
    func clone(ancestry: [FileSyntax]) -> FileSyntax {
        return FileSyntax(outputPath,
                          file,
                          structure,
                          ancestry,
                          tokens,
                          blacklist)
    }

    func clone(substructure: SyntaxStructure) -> FileSyntax {
        return FileSyntax(outputPath,
                          file,
                          substructure,
                          ancestry,
                          tokens,
                          blacklist)
    }

    func match(_ pattern: String) -> Int64? {
        var firstOffendingMatchOffset: Int64?

        do {
            let body = self.file.contents
            let structure = self.structure
            let map = self.tokens

            if let bodyoffset = structure.offset, var bodylength = structure.length {
                if bodyoffset + bodylength > body.count {
                    bodylength = Int64(body.count) - bodyoffset
                }
                if bodyoffset + bodylength <= body.count {
                    let regex = try NSRegularExpression(pattern: pattern, options: [])
                    let nsrange = NSRange(location: Int(bodyoffset), length: Int(bodylength))
                    regex.enumerateMatches(in: body, options: [], range: nsrange) { (match, _, stop) in
                        guard let match = match else { return }

                        let fullBodyOffset = Int64(match.range.location)

                        // check this offset against all of the offsets in the syntax map.  If it is
                        // inside of a comment, then we want to ignore this offset
                        for commentSection in map {
                            if let type = SyntaxKind(rawValue: commentSection.type) {
                                let offset = commentSection.offset.value
                                let length = commentSection.length.value
                                if fullBodyOffset >= offset && fullBodyOffset <= (offset + length) {
                                    switch type {
                                    case .comment, .commentURL, .commentMark, .docComment, .docCommentField, .string, .stringInterpolationAnchor:
                                        return
                                    default:
                                        break
                                    }
                                }
                            }
                        }

                        firstOffendingMatchOffset = fullBodyOffset
                        stop.pointee = true
                    }
                }
            }
        } catch {
            return nil
        }
        return firstOffendingMatchOffset
    }

    func matches(_ pattern: String, _ callback: @escaping ((NSTextCheckingResult, [String]) -> Void)) {
        do {
            let body = self.file.contents
            let structure = self.structure
            let map = self.tokens

            if let bodyoffset = structure.offset, var bodylength = structure.length {
                if bodyoffset + bodylength > body.count {
                    bodylength = Int64(body.count) - bodyoffset
                }
                if bodyoffset + bodylength <= body.count {
                    let regex = try NSRegularExpression(pattern: pattern, options: [])
                    let nsrange = NSRange(location: Int(bodyoffset), length: Int(bodylength))
                    regex.enumerateMatches(in: body, options: [], range: nsrange) { (match, _, _) in
                        guard let match = match else { return }

                        let fullBodyOffset = Int64(match.range.location)

                        // check this offset against all of the offsets in the syntax map.  If it is
                        // inside of a comment, then we want to ignore this offset
                        for commentSection in map {
                            if let type = SyntaxKind(rawValue: commentSection.type) {
                                let offset = commentSection.offset.value
                                let length = commentSection.length.value
                                if fullBodyOffset >= offset && fullBodyOffset <= (offset + length) {
                                    switch type {
                                    case .comment, .commentURL, .commentMark, .docComment, .docCommentField, .string, .stringInterpolationAnchor:
                                        return
                                    default:
                                        break
                                    }
                                }
                            }
                        }
                        var groups: [String] = []
                        for iii in 0..<match.numberOfRanges {
                            if let groupString = body.substring(with: match.range(at: iii)) {
                                groups.append(String(groupString))
                            }
                        }
                        callback(match, groups)
                    }
                }
            }
        } catch { }
    }

    func markup(_ label: String) -> [(ByteCount, String)] {
        let body = self.file.contents
        let structure = self.structure
        let map = self.tokens
        var markup: [(ByteCount, String)] = []

        if let bodyoffset = structure.offset, var bodylength = structure.length {
            if bodyoffset + bodylength > body.count {
                bodylength = Int64(body.count) - bodyoffset
            }
            if bodyoffset + bodylength <= body.count {
                let targetString = "flynnlint:\(label)"
                // Check all comments inside the body to see if they are flynnlint commands
                // flynnlint:<name> <args>
                for commentSection in map {
                    if let type = SyntaxKind(rawValue: commentSection.type) {
                        let offset = commentSection.offset.value
                        if offset >= bodyoffset && offset <= (bodyoffset + bodylength) {
                            switch type {
                            case .comment, .commentURL, .commentMark, .docComment, .docCommentField, .string, .stringInterpolationAnchor:
                                let stringView = StringView.init(body)
                                if let commentString = stringView.substringWithByteRange(commentSection.range) {
                                    if let range = commentString.range(of: targetString) {
                                        markup.append( (commentSection.offset, String(commentString[range.upperBound...])) )
                                    }
                                }
                            default:
                                break
                            }
                        }
                    }
                }
            }
        }
        return markup
    }
}

typealias ASTBuilderResult = ((AST) -> Void)

struct ASTBuilderIterator: IteratorProtocol {
    private var combinedArray: [FileSyntax]
    private var index = -1

    init(_ astBuilder: ASTBuilder) {
        combinedArray = []
        combinedArray.append(contentsOf: Array(astBuilder.classes.values))
        combinedArray.append(contentsOf: Array(astBuilder.protocols.values))
        combinedArray.append(contentsOf: astBuilder.extensions)
        combinedArray.append(contentsOf: astBuilder.calls)
        combinedArray.append(contentsOf: astBuilder.functions)
    }

    mutating func next() -> FileSyntax? {
        index += 1
        if index >= combinedArray.count {
            return nil
        }
        return combinedArray[index]
    }
}

class ASTBuilder: Sequence {
    var classes: [String: FileSyntax] = [:]
    var protocols: [String: FileSyntax] = [:]
    var extensions: [FileSyntax] = []
    var calls: [FileSyntax] = []
    var functions: [FileSyntax] = []
    var files: [FileSyntax] = []

    func add(_ fileSyntax: FileSyntax) {
        files.append(fileSyntax)
        recursiveAdd([], fileSyntax, fileSyntax)
    }

    func recursiveAdd(_ ancestory: [FileSyntax],
                      _ subSyntax: FileSyntax,
                      _ fileSyntax: FileSyntax) {
        let syntax = subSyntax.structure
        
        if syntax.name != nil {
            switch syntax.kind {
            case .class:
                let fullName = AST.getFullName(fileSyntax, ancestory, subSyntax)
                classes[fullName] = subSyntax.clone(ancestry: ancestory)
            case .protocol, .extensionProtocol:
                let fullName = AST.getFullName(fileSyntax, ancestory, subSyntax)
                protocols[fullName] = subSyntax.clone(ancestry: ancestory)
            case .extension, .extensionEnum, .extensionStruct:
                extensions.append(subSyntax)
            case .exprCall:
                calls.append(subSyntax)
            case .functionAccessorAddress, .functionAccessorDidset, .functionAccessorGetter, .functionAccessorModify,
                 .functionAccessorMutableaddress, .functionAccessorRead, .functionAccessorSetter,
                 .functionAccessorWillset, .functionConstructor, .functionDestructor, .functionFree,
                 .functionMethodClass, .functionMethodInstance, .functionMethodStatic, .functionOperator,
                 .functionOperatorInfix, .functionOperatorPostfix, .functionOperatorPrefix, .functionSubscript:
                functions.append(subSyntax)
            default:
                //print("ASTBuilder: unhandled kind \(kind)...")
                break
            }
        }

        if let substructures = syntax.substructure {
            for substructure in substructures {
                recursiveAdd(ancestory + [subSyntax],
                             subSyntax.clone(substructure: substructure),
                             fileSyntax)
            }
        }
    }

    func build() -> AST {
        return AST(classes, protocols, extensions)
    }

    func makeIterator() -> ASTBuilderIterator {
        return ASTBuilderIterator(self)
    }

}

class BuildCombinedAST: Actor, Flowable {
    // input: a File and  a syntax structure
    // output: an immutable AST and pass all syntax
    var safeFlowable = FlowableState()
    private var astBuilder = ASTBuilder()

    override init() {
        super.init()
        unsafePriority = 1
    }

    private func _beFlow(_ args: FlowableArgs) {
        if args.isEmpty == false {
            self.astBuilder.add(args[x:0])
            return
        }

        self.unsafePriority = -1

        // Once we have all of the relevant structures from all of the files captured, we turn that
        // into an immutable struct which will allow us to share that safely with many actors. Then
        // we process eash structure against the rule set.
        let ast = self.astBuilder.build()

        // Run every individual file pass it to the rulesets
        for syntax in self.astBuilder.files {
            self.safeFlowToNextTarget([ast, syntax, true])
        }

        // Run through every syntax structure and pass it to the rulesets
        for syntax in self.astBuilder {
            self.safeFlowToNextTarget([ast, syntax, false])
        }

        self.safeFlowToNextTarget([])
    }

}

// MARK: - Autogenerated by FlynnLint
// Contents of file after this marker will be overwritten as needed

extension BuildCombinedAST {

    @discardableResult
    public func beFlow(_ args: FlowableArgs) -> Self {
        unsafeSend { self._beFlow(args) }
        return self
    }

}
