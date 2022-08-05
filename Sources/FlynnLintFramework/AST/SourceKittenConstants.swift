//
//  main.swift
//  flynnlint
//
//  Created by Rocco Bowling on 5/29/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

// swiftlint:disable force_cast

import Foundation
import SourceKittenFramework
import Flynn

typealias SyntaxStructure = [String: SourceKitRepresentable]

extension SyntaxStructure {
    var accessibility: AccessControlLevel? {
        guard let key = self["key.accessibility"] else { return nil }
        return AccessControlLevel(rawValue: key as! String)
    }

    var attribute: String? { return self["key.attribute"] as? String }
    var attributes: [SyntaxStructure]? { return self["key.attributes"] as? [SyntaxStructure] }
    var bodylength: Int64? { return self["key.bodylength"] as? Int64 }
    var bodyoffset: Int64? { return self["key.bodyoffset"] as? Int64 }
    var diagnosticstage: String? { return self["key.diagnostic_stage"] as? String }
    var elements: [SyntaxStructure]? { return self["key.elements"] as? [SyntaxStructure] }
    var inheritedTypes: [SyntaxStructure]? { return self["key.inheritedtypes"] as? [SyntaxStructure] }
    var kind: SwiftDeclarationKind? { return SwiftDeclarationKind(rawValue: self["key.kind"] as! String) }
    var length: Int64? { return self["key.length"] as? Int64 }
    var name: String? { return self["key.name"] as? String }
    var namelength: Int64? { return self["key.namelength"] as? Int64 }
    var nameoffset: Int64? { return self["key.nameoffset"] as? Int64 }
    var offset: Int64? { return self["key.offset"] as? Int64 }
    var runtimename: String? { return self["key.runtime_name"] as? String }
    var substructure: [SyntaxStructure]? { return self["key.substructure"] as? [SyntaxStructure] }
    var typename: String? { return self["key.typename"] as? String }
    
    var substructureExists: Bool { return self["key.substructure"] != nil }
}

public struct StructureAndSyntax {
    public let structure: [String: SourceKitRepresentable]
    public let syntax: [SyntaxToken]

    public init(sourceKitResponse: [String: SourceKitRepresentable]) {
        structure = sourceKitResponse
        if let data = sourceKitResponse["key.syntaxmap"] as? [SourceKitRepresentable] {
            syntax = data.map { item in
                let dict = item as! [String: SourceKitRepresentable]
                return SyntaxToken(type: dict["key.kind"] as! String, offset: ByteCount(dict["key.offset"] as! Int64),
                                   length: ByteCount(dict["key.length"] as! Int64))
            }
        } else {
            syntax = []
        }
    }

    public init(file: File) throws {
        self.init(sourceKitResponse: try Request.editorOpen(file: file).send())
    }
}

// MARK: - Default to the last item in enum if codable fails

enum CaseIterableDefaultsLastError: Error {
    case error
}

protocol CaseIterableDefaultsLast: Decodable & CaseIterable & RawRepresentable
where RawValue: Decodable, AllCases: BidirectionalCollection { }

extension CaseIterableDefaultsLast {
    public init(from decoder: Decoder) throws {
        do {
            if let converted = Self(rawValue: try decoder.singleValueContainer().decode(RawValue.self)) {
                self = converted
            } else {
                throw CaseIterableDefaultsLastError.error
            }
        } catch {
            print("missing \(try RawValue(from: decoder) as? String ?? "blah")")
            self = Self.allCases.last!
        }
    }
}

// MARK: - Swift Stuff

public enum SwiftDeclarationKind: String, Codable, CaseIterableDefaultsLast {
    /// `associatedtype`.
    case `associatedtype` = "source.lang.swift.decl.associatedtype"
    /// `class`.
    case `class` = "source.lang.swift.decl.class"
    /// `enum`.
    case `enum` = "source.lang.swift.decl.enum"
    /// `enumcase`.
    case enumcase = "source.lang.swift.decl.enumcase"
    /// `enumelement`.
    case enumelement = "source.lang.swift.decl.enumelement"
    /// `extension`.
    case `extension` = "source.lang.swift.decl.extension"
    /// `extension.class`.
    case extensionClass = "source.lang.swift.decl.extension.class"
    /// `extension.enum`.
    case extensionEnum = "source.lang.swift.decl.extension.enum"
    /// `extension.protocol`.
    case extensionProtocol = "source.lang.swift.decl.extension.protocol"
    /// `extension.struct`.
    case extensionStruct = "source.lang.swift.decl.extension.struct"
    /// `function.accessor.address`.
    case functionAccessorAddress = "source.lang.swift.decl.function.accessor.address"
    /// `function.accessor.didset`.
    case functionAccessorDidset = "source.lang.swift.decl.function.accessor.didset"
    /// `function.accessor.getter`.
    case functionAccessorGetter = "source.lang.swift.decl.function.accessor.getter"
    /// `function.accessor.modify`
    //    @available(swift, introduced: 5.0)
    case functionAccessorModify = "source.lang.swift.decl.function.accessor.modify"
    /// `function.accessor.mutableaddress`.
    case functionAccessorMutableaddress = "source.lang.swift.decl.function.accessor.mutableaddress"
    /// `function.accessor.read`
    //    @available(swift, introduced: 5.0)
    case functionAccessorRead = "source.lang.swift.decl.function.accessor.read"
    /// `function.accessor.setter`.
    case functionAccessorSetter = "source.lang.swift.decl.function.accessor.setter"
    /// `function.accessor.willset`.
    case functionAccessorWillset = "source.lang.swift.decl.function.accessor.willset"
    /// `function.constructor`.
    case functionConstructor = "source.lang.swift.decl.function.constructor"
    /// `function.destructor`.
    case functionDestructor = "source.lang.swift.decl.function.destructor"
    /// `function.free`.
    case functionFree = "source.lang.swift.decl.function.free"
    /// `function.method.class`.
    case functionMethodClass = "source.lang.swift.decl.function.method.class"
    /// `function.method.instance`.
    case functionMethodInstance = "source.lang.swift.decl.function.method.instance"
    /// `function.method.static`.
    case functionMethodStatic = "source.lang.swift.decl.function.method.static"
    /// `function.operator`.
    //    @available(swift, obsoleted: 2.2)
    case functionOperator = "source.lang.swift.decl.function.operator"
    /// `function.operator.infix`.
    case functionOperatorInfix = "source.lang.swift.decl.function.operator.infix"
    /// `function.operator.postfix`.
    case functionOperatorPostfix = "source.lang.swift.decl.function.operator.postfix"
    /// `function.operator.prefix`.
    case functionOperatorPrefix = "source.lang.swift.decl.function.operator.prefix"
    /// `function.subscript`.
    case functionSubscript = "source.lang.swift.decl.function.subscript"
    /// `generic_type_param`.
    case genericTypeParam = "source.lang.swift.decl.generic_type_param"
    /// `module`.
    case module = "source.lang.swift.decl.module"
    /// `opaquetype`.
    case opaqueType = "source.lang.swift.decl.opaquetype"
    /// `precedencegroup`.
    case precedenceGroup = "source.lang.swift.decl.precedencegroup"
    /// `protocol`.
    case `protocol` = "source.lang.swift.decl.protocol"
    /// `struct`.
    case `struct` = "source.lang.swift.decl.struct"
    /// `typealias`.
    case `typealias` = "source.lang.swift.decl.typealias"
    /// `var.class`.
    case varClass = "source.lang.swift.decl.var.class"
    /// `var.global`.
    case varGlobal = "source.lang.swift.decl.var.global"
    /// `var.instance`.
    case varInstance = "source.lang.swift.decl.var.instance"
    /// `var.local`.
    case varLocal = "source.lang.swift.decl.var.local"
    /// `var.parameter`.
    case varParameter = "source.lang.swift.decl.var.parameter"
    /// `var.static`.
    case varStatic = "source.lang.swift.decl.var.static"
    /// `elem.typeref`.
    case elemTypeRef = "source.lang.swift.structure.elem.typeref"
    /// `expr.call`.
    case exprCall = "source.lang.swift.expr.call"
    /// `expr.argument`.
    case exprArgument = "source.lang.swift.expr.argument"
    /// `elem.init_expr`.
    case elemInitExpr = "source.lang.swift.structure.elem.init_expr"
    /// `elem.expr`.
    case elemExpr = "source.lang.swift.structure.elem.expr"
    /// `expr.array`.
    case elemExprArray = "source.lang.swift.expr.array"
    /// `comment.mark`.
    case commentMark = "source.lang.swift.syntaxtype.comment.mark"
    /// `expr.closure`.
    case exprClosure = "source.lang.swift.expr.closure"
    /// `expr.tuple`.
    case exprTuple = "source.lang.swift.expr.tuple"
    /// `stmt.brace`.
    case stmtBrace = "source.lang.swift.stmt.brace"
    /// `elem.condition_expr`.
    case elemConditionExpr = "source.lang.swift.structure.elem.condition_expr"
    /// `stmt.if`.
    case stmtIf = "source.lang.swift.stmt.if"
    /// `stmt.switch`.
    case stmtSwitch = "source.lang.swift.stmt.switch"
    /// `elem.pattern`.
    case elemPattern = "source.lang.swift.structure.elem.pattern"
    /// `stmt.case`.
    case stmtCase = "source.lang.swift.stmt.case"
    /// `stmt.guard`.
    case stmtGuard = "source.lang.swift.stmt.guard"
    /// `expr.dictionary`.
    case exprDictionary = "source.lang.swift.expr.dictionary"
    /// `stmt.while`.
    case stmtWhile = "source.lang.swift.stmt.while"
    /// `elem.id`.
    case elemId = "source.lang.swift.structure.elem.id"
    /// `stmt.foreach`.
    case stmtForeach = "source.lang.swift.stmt.foreach"
    /// Unknown
    case unknown
}

public enum AccessControlLevel: String, Codable, CaseIterableDefaultsLast {
    /// Accessible by the declaration's immediate lexical scope.
    case `private` = "source.lang.swift.accessibility.private"
    /// Accessible by the declaration's same file.
    case `fileprivate` = "source.lang.swift.accessibility.fileprivate"
    /// Accessible by the declaration's same module, or modules importing it with the `@testable` attribute.
    case `internal` = "source.lang.swift.accessibility.internal"
    /// Accessible by the declaration's same program.
    case `public` = "source.lang.swift.accessibility.public"
    /// Accessible and customizable (via subclassing or overrides) by the declaration's same program.
    case `open` = "source.lang.swift.accessibility.open"
    /// Unknown
    case unknown
}
