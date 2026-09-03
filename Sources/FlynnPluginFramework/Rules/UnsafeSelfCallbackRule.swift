import Foundation
import SourceKittenFramework

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
                        other.beRegister(Flynn.any) { result in
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
                        other.beFoo(Flynn.any) { result in
                            self.count += 1
                        }
                    }
                }
            """),
            Example("""
                class WhoseCallWasThisAnyway: Actor {
                    init {
                        ScriptManager.shared.beGet(Flynn.any) {
                            self.something = 5
                        }
                    }
                }
            """),
            Example("""
                class SomeActor: Actor {
                    init() {
                        super.init()
                        Flynn.Timer(timeInterval: 1, immediate: true, repeats: true, Flynn.any) { [weak self] _ in
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
                
                if let closureArg = arguments.popLast(),
                   let selfArg = arguments.popLast(),
                   closureArg.hasPrefix("{"),
                   closureArg.hasSuffix("}"),
                   selfArg != "self" {
                    
                    if closureArg.contains("self.") ||
                        closureArg.contains("self?.") {
                        output.append(warning(substructure.offset, syntax))
                        return false
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
