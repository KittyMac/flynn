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
    func usesSelf(in structure: SyntaxStructure,
                  _ offset: inout Int64) -> Bool {
        let tokens = syntaxTokens(in: structure)
        guard tokens.count > 0 else { return true }
        for idx in 0..<tokens.count-1 {
            let token = tokens[idx]
            let next = tokens[idx+1]
            
            if token.type == SyntaxKind.keyword.rawValue && text(for: token) == "self" {
                if let nextText = text(for: next) {
                    if nextText == "safeThen" {
                        continue
                    }
                    if nextText == "unsafeSend" {
                        // ideally we would walk past the contents of the unsafeSend closure,
                        // however we cannot do that with just a tokens listing
                        return false
                    }
                    if nextText.hasPrefix("unsafe") {
                        // calling unsafe values on self would be allowed
                        continue
                    }
                    offset = Int64(token.offset.value)
                    return true
                }
            }
        }
        
        return false
    }
}

struct UnsafeSelfCallbackRule: Rule {

    let description = RuleDescription(
        identifier: "unsafe_self_behaviour_callback",
        name: "Unsafe Self Violation",
        description: "self referenced in a callback executed on a different actor or thread",
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
            Example("""
                class SomeActor: Actor {
                    init(other: OtherActor) {
                        super.init()
                        other.beRegister(Flynn.any) { result in
                            self.unsafeSend {
                                self.beThis()
                            }
                            print("HI")
                        }
                    }
                }
            """),
            Example("""
                class SomeActor: Actor {
                    init(other: OtherActor) {
                        httpSession.beBegin(urlSession: urlSession) { urlSession in
                            self.unsafeSend { _ in
                                self.waitingURLSessions.append(urlSession)
                                self.checkForMoreSessions()
                            }
                        }
                    }
                }
            """),
            Example("""
                class SomeActor: Actor {
                    init(other: OtherActor) {
                        HTTPDeliveryManager.shared.beDeliver(url: url.toString(),
                                                             httpMethod: "PUT",
                                                             params: [:],
                                                             headers: [:],
                                                             proxy: nil,
                                                             body: body,
                                                             sender) { data, response, error in
                            returnCallback(data, response, error)
                            group.wait()
                            self.safeThen(unsafeThenPtr)
                        }
                    }
                }
            """),
            Example("""
                class SomeActor: Actor {
                    private var value: Int = 0
                    func safeRead() -> Int { return value }
                    internal func _beStart() {
                        unsafeSend { _ in
                            _ = self.safeRead()
                        }
                    }
                }
            """),
            Example("""
                class SomeActor: Actor {
                    private var value: Int = 0
                    func safeRead() -> Int { return value }
                    internal func _beStart() {
                        Flynn.Timer(timeInterval: 0.1, repeats: false, self) { [weak self] _ in
                            _ = self?.safeRead()
                        }
                    }
                }
            """),
            Example("""
                class SomeActor: Actor {
                    init() {
                        super.init()
                    }
                    internal func _beStartup() {
                        beCheckDB()
                    }
                }
            """),
            Example("""
                  class Counter: Actor, Timerable {
                      private func apply(_ value: Int) {
                          let group = DispatchGroup()
                          group.notify(actor: self) {
                              let _ = self.counter
                          }
                      }
                  }
            """),
            Example("""
                  class Counter: Actor, Timerable {
                      private func apply(_ value: Int) {
                          dispatchQueue.sync {
                              let _ = self.counter
                          }
                      }
                  }
            """)
        ],
        triggeringExamples: [
            Example("""
                class SomeActor: Actor {
                    private var value: Int = 0
                    func safeRead() -> Int { return value }
                    internal func _beStart(_ other: OtherActor) {
                        other.beGet(Flynn.any) { _ in
                            _ = self.safeRead()
                        }
                    }
                }
            """),
            Example("""
                class SomeActor: Actor {
                    private var value: Int = 0
                    func safeRead() -> Int { return value }
                    internal func _beStart(_ other: OtherActor) {
                        other.unsafeSend { _ in
                            _ = self.safeRead()
                        }
                    }
                }
            """),
            Example("""
                class SomeActor: Actor {
                    private var value: Int = 0
                    func safeRead() -> Int { return value }
                    internal func _beStart(_ other: OtherActor) {
                        Flynn.Timer(timeInterval: 0.1, repeats: false, other) { _ in
                            _ = self.safeRead()
                        }
                    }
                }
            """),
            Example("""
                class SomeActor: Actor {
                    private var value: Int = 0
                    func safeRead() -> Int { return value }
                    init(other: OtherActor) {
                        super.init()
                        Flynn.Timer(timeInterval: 0.1, repeats: true, other) { [weak self] _ in
                            _ = self?.safeRead()
                        }
                    }
                }
            """),
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
            """),
            Example("""
                class SomeActor: Actor {
                    init() {
                        super.init()
                    }
                    
                    internal func _beStartup() {
                        beLoad(Flynn.any) { error in
                            roverServerAuthorization = self.disConfig[hitch: "roverServerAuthorization"]
                        }
                    }
                }
            """),
            Example("""
                class Counter: Actor, Timerable {
                    private func apply(_ value: Int) {
                        counter += value
                        
                        beGetValue(Flynn.any) { v in
                            let x = self.counter

                            self.beGetValue(Flynn.any) { v in
                                //let y = self.counter
                                
                            }
                        }
                    }
                }
            """),
            Example("""
                class Counter: Actor, Timerable {
                    private func apply(_ value: Int) {
                        counter += value
                        Thread {
                            let x = self.counter
                        }.start()
                    }
                }
            """),
            Example("""
                class Counter: Actor, Timerable {
                    private func apply(_ value: Int) {
                        counter += value
                        Task {
                            let x = self.counter
                        }
                    }
                }
            """),
            Example("""
                class Counter: Actor, Timerable {
                    private func apply(_ value: Int) {
                        let handle = FileHandle.standardInput
                        handle.readabilityHandler = { fh in
                            let _ = self.counter
                        }
                    }
                }
            """),
            Example("""
                  class Counter: Actor, Timerable {
                      private func apply(_ value: Int) {
                          let handle = FileHandle.standardInput
                          handle.readabilityHandler = { fh in
                              let _ = self.counter
                          }
                      }
                  }
            """),
            Example("""
                  class Counter: Actor, Timerable {
                      private func apply(_ value: Int) {
                          let opetationQueue = OperationQueue()
                          opetationQueue.addOperation {
                              let _ = self.counter
                          }
                      }
                  }
            """),
            Example("""
                  class Counter: Actor, Timerable {
                      private func apply(_ value: Int) {
                          let dispatchQueue = DispatchQueue(label: "some.queue")
                          dispatchQueue.async {
                              let _ = self.counter
                          }
                      }
                  }
            """),
            Example("""
                  class Counter: Actor, Timerable {
                      private func apply(_ value: Int) {
                          DispatchQueue.main.async {
                              let _ = self.counter
                          }
                      }
                  }
            """),
            Example("""
                  class Counter: Actor, Timerable {
                      private func apply(_ value: Int) {
                          DispatchQueue.global(qos: .background).async {
                              let _ = self.counter
                          }
                      }
                  }
            """),
            Example("""
                  class Counter: Actor, Timerable {
                      private func apply(_ value: Int) {
                          queue.asyncAfter(deadline: .now() + 1) {
                              let _ = self.counter
                          }
                      }
                  }
            """),
            Example("""
                  class Counter: Actor, Timerable {
                      private func apply(_ value: Int) {
                          DispatchQueue.concurrentPerform(iterations: 10) { index in
                              let _ = self.counter
                          }
                      }
                  }
            """),
            Example("""
                  class Counter: Actor, Timerable {
                      private func apply(_ value: Int) {
                          let workItem = DispatchWorkItem {
                              let _ = self.counter
                          }
                          queue.async(execute: workItem)
                      }
                  }
            """),
            Example("""
                  class Counter: Actor, Timerable {
                      private func apply(_ value: Int) {
                          workItem.notify(queue: .main) {
                              let _ = self.counter
                          }
                      }
                  }
            """),
            Example("""
                  class Counter: Actor, Timerable {
                      private func apply(_ value: Int) {
                          let timer = DispatchSource.makeTimerSource(queue: queue)
                          timer.setEventHandler {
                              let _ = self.counter
                          }
                      }
                  }
            """),
            Example("""
                  class Counter: Actor, Timerable {
                      private func apply(_ value: Int) {
                          timer.setCancelHandler {
                              let _ = self.counter
                          }
                      }
                  }
            """),
            Example("""
                  class Counter: Actor, Timerable {
                      private func apply(_ value: Int) {
                          Thread.detachNewThread {
                              let _ = self.counter
                          }
                      }
                  }
            """),
            Example("""
                  class Counter: Actor, Timerable {
                      private func apply(_ value: Int) {
                          let blockOp = BlockOperation {
                              let _ = self.counter
                          }
                      }
                  }
            """),
            Example("""
                  class Counter: Actor, Timerable {
                      private func apply(_ value: Int) {
                          blockOp.addExecutionBlock {
                              let _ = self.counter
                          }
                      }
                  }
            """),
            Example("""
                  class Counter: Actor, Timerable {
                      private func apply(_ value: Int) {
                          blockOp.completionBlock = {
                              let _ = self.counter
                          }
                      }
                  }
            """),
            Example("""
                  class Counter: Actor, Timerable {
                      private func apply(_ value: Int) {
                          OperationQueue.main.addOperation {
                              let _ = self.counter
                          }
                      }
                  }
            """),
            Example("""
                  class Counter: Actor, Timerable {
                      private func apply(_ value: Int) {
                          let url = URL(fileURLWithPath: "/tmp")
                          URLSession.shared.dataTask(with: url) { data, response, error in
                              let _ = self.counter
                          }.resume()
                      }
                  }
            """),
            Example("""
                  class Counter: Actor, Timerable {
                      private func apply(_ value: Int) {
                          let handle = FileHandle.standardInput
                          handle.readabilityHandler = { fh in
                              let _ = self.counter
                          }
                      }
                  }
            """),
            Example("""
                  class Counter: Actor, Timerable {
                      private func apply(_ value: Int) {
                          let group = DispatchGroup()
                          group.notify(actor: Flynn.any) {
                              let _ = self.counter
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
    
    func recurseBehaviourCallsFailOnSelf(_ ast: AST,
                                         _ syntax: FileSyntax,
                                         _ substructures: [SyntaxStructure],
                                         _ offset: inout Int64) -> Bool {
        // We are inside a closure which does not run on the current actor; references to
        // self should be flagged as errors
        for substructure in substructures {
            
            if let name = substructure.name {
                if substructure.kind == .exprCall,
                   name.hasSuffix("unsafeSend") {
                    continue
                }
                if substructure.kind == .exprCall,
                   name.hasSuffix("safeThen") {
                    continue
                }
                
                if name.hasPrefix("self.") {
                    if let substructureOffset = substructure.offset {
                        offset = substructureOffset
                    }
                    return false
                }
            }
            
            
            
            if let substructures = substructure.substructure {
                let passed = recurseBehaviourCallsFailOnSelf(ast, syntax, substructures, &offset)
                if (!passed) {
                    return false
                }
            }
        }
        return true
    }
        
    func recurseBehaviourCalls(_ ast: AST,
                               _ syntax: FileSyntax,
                               _ substructures: [SyntaxStructure],
                               _ output: inout [PrintError.Packet]) -> Bool {
        let body = syntax.file.contents
        
        // do we contain behaviour calls which are not wrapped in unsafeSend?
        for substructure in substructures {
            
            if substructure.kind == .exprCall,
               substructure.name == "unsafeSend" || substructure.name == "self.unsafeSend" {
                continue
            }
            
            var examineStructure = false
            
            if substructure.kind == .exprCall,
               let callName = substructure.name,
               callName.hasSuffix(".unsafeSend") {
                examineStructure = true
            }
            
            // like: handle.readabilityHandler = { fh in
            //    let _ = self.counter
            // }
            // but only yhe closure part; the set on the variable is
            // blind to the substructure
            if substructure.kind == .exprClosure,
               substructure.name == nil,
               let offset = substructure.offset {
                // if this follows the above = { } then we should
                // see if its a name we care about
                let arr = Array(body)
                var ptr = Int(clamping: offset)
                
                if ptr > 3,
                   arr[ptr-1] == "=" || arr[ptr-2] == "=" {
                    while ptr > 0 && arr[ptr-1] != "\n" {
                        ptr -= 1
                    }
                    let precursor = body.substring(with:  NSRange(location: ptr, length: Int(Int(offset) - ptr)))
                    if precursor?.hasSuffix("Block = ") == true ||
                        precursor?.hasSuffix("block = ") == true ||
                        precursor?.hasSuffix("Handler = ") == true ||
                        precursor?.hasSuffix("handler = ") == true ||
                        precursor?.hasSuffix("Callback = ") == true ||
                        precursor?.hasSuffix("callback = ") == true ||
                        precursor?.contains(".completionBlock") == true ||
                        precursor?.contains(".readabilityHandler") == true ||
                        precursor?.contains(".terminationHandler") == true ||
                        precursor?.contains(".stateUpdateHandler") == true {
                        examineStructure = true
                    }
                }
            }
            
            if substructure.kind == .exprCall,
                substructure.name == "Task" ||
                substructure.name == "Thread" ||
                substructure.name == "DispatchWorkItem" ||
                substructure.name == "BlockOperation" ||
                substructure.name == "withTaskGroup" ||
                substructure.name == "withThrowingTaskGroup" ||
                substructure.name == "withTaskCancellationHandler" ||
                substructure.name == "withCheckedContinuation" ||
                substructure.name == "AsyncStream" ||
                
                substructure.name?.hasPrefix("be") == true ||
                substructure.name?.contains(".be") == true ||
                substructure.name?.contains(".do") == true ||
                substructure.name?.contains(".addOperation") == true ||
                substructure.name?.contains(".async") == true ||
                substructure.name?.contains(".notify") == true ||
                substructure.name?.contains(".concurrentPerform") == true ||
                
                substructure.name?.contains(".setEventHandler") == true ||
                substructure.name?.contains(".setCancelHandler") == true ||
                substructure.name?.contains(".detachNewThread") == true ||
                substructure.name?.contains(".addExecutionBlock") == true ||
                substructure.name?.contains(".completionBlock") == true ||
                substructure.name?.contains(".addBarrierBlock") == true ||
                
                substructure.name?.contains(".detached") == true ||
                substructure.name?.contains(".run") == true ||
                substructure.name?.contains(".addTask") == true ||
                substructure.name?.contains(".observe") == true ||
                
                substructure.name?.contains(".scheduledTimer") == true ||
                substructure.name?.contains(".perform") == true ||
                substructure.name?.contains(".addObserver") == true ||
                
                substructure.name?.contains(".dataTask") == true ||
                substructure.name?.contains(".uploadTask") == true ||
                substructure.name?.contains(".downloadTask") == true ||
                substructure.name?.contains(".animate") == true ||
                substructure.name?.contains(".readabilityHandler") == true ||
                substructure.name?.contains(".terminationHandler") == true ||
                substructure.name?.contains(".stateUpdateHandler") == true ||
                
                substructure.name == "Flynn.Timer" {
                
                examineStructure = true
            }
            
            if examineStructure {
                // does this behaviour call back to self?  this requires:
                // the last argument to be a closure
                // the second to last argument to be self
                // things like beSend(self) {  }
                var arguments: [String] = []
                for substructure in substructure.substructure ?? [] {
                    if substructure.kind == .exprArgument,
                       let bodyoffset = substructure.offset,
                       let bodylength = substructure.length,
                       let value = body.substring(with: NSRange(location: Int(bodyoffset), length: Int(bodylength))) {
                        arguments.append(value.description)
                    }
                }
                
                // things like handle.readabilityHandler = { }
                if substructure.kind == .exprClosure,
                   let bodyoffset = substructure.offset,
                   let bodylength = substructure.length,
                   let value = body.substring(with: NSRange(location: Int(bodyoffset), length: Int(bodylength))) {
                    arguments.append(value.description)
                }
                
                if let closureArg = arguments.popLast(),
                   closureArg.hasPrefix("{"),
                   closureArg.hasSuffix("}") {
                    if arguments.last != "self" && arguments.last != "actor: self" && arguments.last != "actor:self" {
                        // examine the closure for uses of self. we need to
                        // pre-handle some valid cases:
                        // self.unsafe anything should be ignored (and their closure contents)
                        if let finalClosureStructure = closureArg.syntaxStructure {
                            if let substructures = finalClosureStructure.substructure {
                                var offset: Int64 = 0
                                let passed = recurseBehaviourCallsFailOnSelf(ast, syntax, substructures, &offset)
                                if (!passed) {
                                    output.append(error((substructure.offset ?? 0) + offset, syntax))
                                    return false
                                }
                            }
                        }
                        
                        var offset: Int64 = 0
                        if let finalClosureStructure = closureArg.syntaxStructure,
                           closureArg.usesSelf(in: finalClosureStructure, &offset) {
                            output.append(error((substructure.substructure?.last?.offset ?? 0) + offset, syntax))
                            return false
                        }
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
                        if function.kind == .functionMethodInstance ||
                           function.kind == .functionConstructor,
                           let substructures = function.substructure {
                            if recurseBehaviourCalls(ast, syntax, substructures, &output) == false {
                                allPassed = false
                            }
                        }
                    }
                }
            }
        }

        return allPassed
    }
}
