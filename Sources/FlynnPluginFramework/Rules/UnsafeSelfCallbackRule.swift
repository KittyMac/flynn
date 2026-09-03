import Foundation
import SourceKittenFramework

extension SyntaxStructure {
    /// Non-trapping `kind`. The existing `.kind` force unwraps "key.kind", which
    /// the root structure does not have; use this when walking arbitrary nodes.
    var kindOrNil: SwiftDeclarationKind? {
        guard let raw = self["key.kind"] as? String else { return nil }
        return SwiftDeclarationKind(rawValue: raw)
    }
}

extension String {
    /// Parse this string as Swift source. One SourceKit request; use this when you
    /// need both the structure and the syntax tokens.
    var syntax: StructureAndSyntax? {
        return try? StructureAndSyntax(file: File(contents: self))
    }

    /// The root SyntaxStructure (the whole "file"); use .substructure to descend.
    var syntaxStructure: SyntaxStructure? {
        return syntax?.structure
    }

    /// Top-level SyntaxStructures. [] if SourceKit returns nothing.
    var syntaxStructures: [SyntaxStructure] {
        return syntaxStructure?.substructure ?? []
    }

    /// The syntax token map. NOTE: the structure only contains declarations and
    /// calls - assignments and bare member accesses (self.counter = x) never appear
    /// in it. Tokens are how you see those.
    var syntaxTokens: [SyntaxToken] {
        return syntax?.syntax ?? []
    }

    /// Source text for a token. nil if the token's byte range is out of bounds or
    /// does not land on a character boundary.
    func text(for token: SyntaxToken) -> String? {
        return text(offset: Int(token.offset.value), length: Int(token.length.value))
    }

    /// Source text for a byte offset/length pair (SourceKit offsets are UTF-8 bytes).
    func text(offset: Int, length: Int) -> String? {
        let bytes = Array(utf8)
        guard offset >= 0, length >= 0, offset + length <= bytes.count else { return nil }
        return String(bytes: bytes[offset..<(offset + length)], encoding: .utf8)
    }

    /// Tokens falling inside a structure's byte range - eg the tokens of one closure.
    /// Includes tokens of anything nested inside it.
    func syntaxTokens(in structure: SyntaxStructure) -> [SyntaxToken] {
        guard let offset = structure.offset, let length = structure.length else { return [] }
        let start = offset, end = offset + length
        return syntaxTokens.filter {
            let tokenStart = Int64($0.offset.value)
            let tokenEnd = tokenStart + Int64($0.length.value)
            return tokenStart >= start && tokenEnd <= end
        }
    }

    /// True if `self` is referenced anywhere inside this structure. `self` is a
    /// keyword token, so strings and comments cannot produce a false positive.
    func usesSelf(in structure: SyntaxStructure, _ output: inout [PrintError.Packet]) -> Bool {
        for token in syntaxTokens(in: structure)
        where token.type == SyntaxKind.keyword.rawValue && text(for: token) == "self" {
            return true
        }
        return false
    }
}

struct UnsafeSelfCallbackRule: Rule {

    let description = RuleDescription(
        identifier: "unsafe_self_behaviour_callback",
        name: "Unsafe Self Violation",
        description: "self referenced in a behaviour callback executed on a different actor",
        syntaxTriggers: [.class, .extension],
        nonTriggeringExamples: [
            Example("class SomeClass {}\n"),
            Example("class SomeActor: Actor {}\n"),
            Example("""
                class SomeActor: Actor {
                    private var data: OffToTheRacesData
                    init(_ data: OffToTheRacesData) {
                        self.data = data
                        super.init()
                        self.unsafePriority = 99
            
                        unsafeGetRunnerForActor(actor.unsafeRunnerIdx).beHandleMessage(actor, behavior, data, messageID, replySocketFD)
                    }
                }
            """),
            Example("""
                class SomeActor: Actor {
                    private let count: Int
                    init(count: Int) {
                        self.count = count
                    }
                    convenience init() {
                        self.init(count: 0)
                    }
                }
            """),
            Example("""
                class SomeActor: Actor {
                    private var timer: Flynn.Timer?
                    internal func _beStart() {
                        timer = Flynn.Timer(timeInterval: 1, repeats: true, unsafeSender: self) { [weak self] _ in
                            self?.unsafePriority = 1
                        }
                    }
                }
            """),
            Example("""
                class SomeClass {
                    init(other: SomeRegistry) {
                        other.register(self)
                    }
                }
            """),
            Example("""
                class WhoseCallWasThisAnyway: Actor {
                    init {
                        unsafeSend { _ in
                            ScriptManager.shared.beGet(unsafeSender: self) {
                                print("HERE")
                            }
                        }
                    }
                }
            """),
            Example("""
                class SomeActor: Actor {
                    init() {
                        super.init()
                        Flynn.Timer(timeInterval: 1, immediate: false, repeats: true, unsafeSender: self) { [weak self] _ in
                            self?.unsafePriority = 1
                        }
                    }
                }
            """),
            Example("""
                class SomeActor: Actor {
                    init() {
                        super.init()
                        Flynn.Timer(timeInterval: 1, repeats: true, unsafeSender: self) { [weak self] _ in
                            self?.unsafePriority = 1
                        }
                    }
                }
            """),
            Example("""
                class SomeActor: Actor {
                    init(registry: SomeRegistry) {
                        super.init()
                        registry.current = self
                    }
                }
            """),
            Example("""
                class SomeActor: Actor {
                    init(other: OtherActor) {
                        super.init()
                        other.beRegister(Flynn.any) { result in
                            print("HI")
                        }
                    }
                }
            """),
        ],
        triggeringExamples: [
            Example("""
                class SomeActor: Actor {
                    init(other: OtherActor) {
                        super.init()
                        other.beRegister(unsafeSender: Flynn.any) { result in
                            self.something = true
                        }
                    }
                }
            """),
            Example("""
                class SomeActor: Actor {
                    private var count = 0
                    init(other: OtherActor) {
                        super.init()
                        other.beFoo(unsafeSender: Flynn.any) { result in
                            self.count += 1
                        }
                    }
                }
            """),
            Example("""
                class WhoseCallWasThisAnyway: Actor {
                    init {
                        ScriptManager.shared.beGet(unsafeSender: Flynn.any) {
                            self.something = 5
                        }
                    }
                }
            """),
            Example("""
                class SomeActor: Actor {
                    init() {
                        super.init()
                        Flynn.Timer(timeInterval: 1, immediate: true, repeats: true, unsafeSender: Flynn.any) { [weak self] _ in
                            self?.unsafePriority = 1
                        }
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
        
    func recurseBehaviourCalls(_ ast: AST, _ syntax: FileSyntax, _ substructures: [SyntaxStructure], _ output: inout [PrintError.Packet]) -> Bool {
        // do we contain behaviour calls which are not wrapped in unsafeSend?
        for substructure in substructures {
            if substructure.kind == .exprCall,
               substructure.name == "unsafeSend" {
                continue
            }
            if substructure.kind == .exprCall,
               substructure.name?.contains(".be") == true ||
               substructure.name?.contains(".do") == true ||
                substructure.name == "Flynn.Timer" {
                let body = syntax.file.contents
                
                // does this behaviour call back to self?  this requires:
                // the last argument to be a closure
                // the second to last argument to be self
                var arguments: [String] = []
                for substructure in substructure.substructure ?? [] {
                    if substructure.kind == .exprArgument,
                       let bodyoffset = substructure.offset,
                       let bodylength = substructure.length,
                       let value = body.substring(with: NSRange(location: Int(bodyoffset), length: Int(bodylength))) {
                        arguments.append(value.description)
                    }
                }
                
                // if we are Flynn.Timer and we have immediate: true then we might be in trouble
                if substructure.name == "Flynn.Timer" && arguments.contains("immediate: true") == false {
                    continue
                }
                
                // Need to support the following:
                // inferred self: beAdd(x: counter, y: 1) { result in
                // unsafeSender self: beAdd(x: counter, y: 1, unsafeSender: self) { result in
                // unsafeSender to other: beAdd(x: counter, y: 1, unsafeSender: actor) { result in
                if let closureArg = arguments.popLast(),
                   closureArg.hasPrefix("{"),
                   closureArg.hasSuffix("}") {
                    
                    if let selfArg = arguments.popLast(),
                       selfArg.contains("unsafeSender"),
                       selfArg != "unsafeSender: self" {
                        if let finalClosureStructure = closureArg.syntaxStructure,
                           closureArg.usesSelf(in: finalClosureStructure, &output) {
                            output.append(error(substructure.offset, syntax))
                            return false
                        }
                    } else {
                        // no argument other than the closure means we're inferred self
                    }
                }
            }
            
            if let substructures = substructure.substructure {
                let passed = recurseBehaviourCalls(ast, syntax, substructures, &output)
                if (!passed) {
                    return false
                }
            }
        }
        return true
    }

    func check(_ ast: AST, _ syntax: FileSyntax, _ output: inout [PrintError.Packet]) -> Bool {
        
        var allPassed = true
        
        // print(syntax.structure.substructure)
        if let resolvedClass = ast.getClassOrProtocol(syntax.structure.name) {
            if ast.isActor(resolvedClass) {
                if let functions = syntax.structure.substructure {
                    for function in functions {
                        if function.kind == .functionMethodInstance,
                           let substructures = function.substructure {
                            allPassed = recurseBehaviourCalls(ast, syntax, substructures, &output)
                        }
                    }
                }
            }
        }

        return allPassed
    }
}
