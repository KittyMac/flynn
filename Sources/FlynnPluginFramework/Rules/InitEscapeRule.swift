import Foundation
import SourceKittenFramework

// Actors in Flynn are "live" the moment the underlying pony actor is created,
// which happens in Actor.init(). The body of a subclass's init, however, runs
// synchronously on the constructing thread, *not* as a message on the actor.
//
// If self is allowed to escape from within init -- passed as an argument to
// another actor, assigned to some other storage, or captured by a closure --
// then messages can be delivered to (and executed on) this actor while init
// is still running. This results in two threads concurrently accessing the
// actor's state, violating the safety guarantees of the actor model.
//
// The correct pattern is to keep init limited to initializing state, and to
// perform any work which needs to hand out self in a behavior called after
// construction:
//
//     let manager = RoverManager()
//     manager.beConnect(info, maxConnections)
//
// This rule flags three escape vectors inside an Actor's init:
//   1. self passed as a bare argument to a call:      other.beRegister(self)
//   2. self assigned to anything:                     registry.current = self
//   3. self referenced inside a closure:              other.beFoo { self.x += 1 }
//
// Note that Swift requires explicit `self.` (or an explicit capture list)
// inside escaping closures, so vector 3 reliably contains the token `self`
// whenever an escaping closure captures the actor.

struct InitEscapeRule: Rule {

    let description = RuleDescription(
        identifier: "actors_self_escapes_init",
        name: "Init Escape Violation",
        description: "self should not escape an Actor's init; the actor can process messages before init completes. Perform this work in a behavior called after construction",
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
                        timer = Flynn.Timer(timeInterval: 1, repeats: true, self) { [weak self] _ in
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
                            ScriptManager.shared.beGet(self) {
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
                        Flynn.Timer(timeInterval: 1, immediate: false, repeats: true, self) { [weak self] _ in
                            self?.unsafePriority = 1
                        }
                    }
                }
            """),
            Example("""
                class SomeActor: Actor {
                    init() {
                        super.init()
                        Flynn.Timer(timeInterval: 1, repeats: true, self) { [weak self] _ in
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
            """)
        ],
        triggeringExamples: [
            Example("""
                class SomeActor: Actor {
                    init(other: OtherActor) {
                        super.init()
                        other.beRegister(self) { }
                    }
                }
            """),
            Example("""
                class SomeActor: Actor {
                    private var count = 0
                    init(other: OtherActor) {
                        super.init()
                        other.beFoo(self) { result in
                            self.count += 1
                        }
                    }
                }
            """),
            Example("""
                class WhoseCallWasThisAnyway: Actor {
                    init {
                        ScriptManager.shared.beGet(self) {
                            print("HERE")
                        }
                    }
                }
            """),
            Example("""
                class SomeActor: Actor {
                    init() {
                        super.init()
                        Flynn.Timer(timeInterval: 1, immediate: true, repeats: true, self) { [weak self] _ in
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
                
                if let _ = arguments.popLast(),
                   let selfArg = arguments.popLast(),
                   selfArg == "self" {
                    output.append(error(substructure.offset, syntax, description.console("unsafe behaviour call in init; wrap with unsafeSend")))
                    return false
                } else {
                    // output.append(warning(substructure.offset, syntax, description.console("potentially unsafe behaviour call in init; wrap with unsafeSend")))
                    // return false
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
                        let functionName = (function.name ?? "")
                        
                        if functionName.hasPrefix("init("),
                           function.kind == .functionMethodInstance,
                           let substructures = function.substructure {
                            allPassed = recurseBehaviourCalls(ast, syntax, substructures, &output)
                        }
                        
                        /*
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
*/
                    }
                }
            }
        }

        return allPassed
    }
}
