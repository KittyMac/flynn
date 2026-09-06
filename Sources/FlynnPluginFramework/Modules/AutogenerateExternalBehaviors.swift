import Foundation
import SourceKittenFramework


let importsRegexString = #"import\s+([\w\d]*)"#

private func codableName(_ name: String) -> String {
    let cappedName = name.prefix(1).capitalized + name.dropFirst()
    return "\(cappedName)Codable"
}

class AutogenerateExternalBehaviors {
    // input: an AST and one syntax structure
    // output: an AST and one syntax structure

    // MARK: - ACTOR
    private func createActorExtensionIfRequired(_ syntax: FileSyntax,
                                                _ ast: AST,
                                                _ numOfExtensions: inout Int,
                                                _ newExtensionString: inout String,
                                                _ actorSyntax: FileSyntax,
                                                _ disableFatalErrors: Bool) {
        let fullActorName = AST.getFullName(syntax,
                                            actorSyntax.ancestry,
                                            actorSyntax)
        
        if  actorSyntax.file == syntax.file &&
            ast.isActor(fullActorName) {

            let (internals, _) = ast.getBehaviorsForActor(actorSyntax)
            
            if internals.count > 0 {
                var didHaveBehavior = false

                var scratch = ""
                scratch.append("\n")
                scratch.append("extension \(fullActorName) {\n\n")

                var minParameterCount = 0
                var returnCallbackParameters: [String] = []
                var hasReturnCallback = false

                let checkParametersForRemoteCallback = { (behavior: AST.Behavior) in
                    hasReturnCallback = false
                    minParameterCount = 0
                    returnCallbackParameters = []
                    if let parameters = behavior.function.structure.substructure {
                        for parameter in parameters where parameter.kind == .varParameter {
                            if let typename = parameter.typename {
                                if parameter.name == "returnCallback" {
                                    minParameterCount = 1

                                    let (callbackParameters, _) = ast.parseClosureType(typename)
                                    returnCallbackParameters = callbackParameters
                                    hasReturnCallback = true
                                }
                            }
                        }
                    }
                }

                for behavior in internals where behavior.function.file.path == syntax.file.path && behavior.function.structure.name != nil {
                    checkParametersForRemoteCallback(behavior)

                    didHaveBehavior = true

                    let createBehaviour: (Bool) -> () = { supportsThen in
                        // Note: The information we need comes from two places:
                        // 1. behavior.function.structure.name is formatted like this:
                        //    _beSetCoreAffinity(theAffinity:arg2:)
                        
                        let (name, parameterLabels) = ast.parseFunctionDefinition(behavior.function.structure)
                        var returnType = behavior.function.structure.typename
                        if returnType == "Void" {
                            returnType = nil
                        }
                        if returnType == nil && hasReturnCallback {
                            returnType = "Void"
                        }
                        
                        var behaviourName = name
                        if supportsThen {
                            behaviourName = "do" + behaviourName.dropFirst(2)
                        }
                        
                        // 2. the names and type of the parameters are in the substructures
                        if behavior.function.structure.has(attribute: .inlinable) {
                            scratch.append("    @inlinable\n")
                        }
                        scratch.append("    @discardableResult\n")
                        let functionNameHeader = "    public func \(behaviourName)("
                        scratch.append(functionNameHeader)
                        let parameterNameHeader = String(repeating: " ", count: functionNameHeader.count)
                        if parameterLabels.count > minParameterCount {
                            if let parameters = behavior.function.structure.substructure {
                                var idx = 0
                                for parameter in parameters where parameter.kind == .varParameter && parameter.name != "returnCallback" {
                                    let label = parameterLabels[idx]
                                    
                                    if idx != 0 {
                                        scratch.append(parameterNameHeader)
                                    }
                                    
                                    if let typename = parameter.typename,
                                       let name = parameter.name {
                                        let typename = AST.getFullName(syntax, typename)
                                        if label == name {
                                            scratch.append("\(name): \(typename),\n")
                                        } else {
                                            scratch.append("\(label) \(name): \(typename),\n")
                                        }
                                    }
                                    idx += 1
                                }
                            }
                        }
                        
                        if let returnType = returnType {
                            if parameterLabels.count > minParameterCount {
                                scratch.append(parameterNameHeader)
                            }
                            scratch.append("_ sender: Actor,\n")
                            
                            if hasReturnCallback {
                                scratch.append("\(parameterNameHeader)_ callback: @escaping ((")
                                for type in returnCallbackParameters {
                                    scratch.append("\(type), ")
                                }
                                if scratch.hasSuffix(", ") {
                                    scratch.removeLast()
                                    scratch.removeLast()
                                }
                                scratch.append(") -> Void)")
                            } else {
                                scratch.append("\(parameterNameHeader)_ callback: @escaping ((\(returnType)) -> Void)")
                            }
                        } else {
                            if scratch.hasSuffix(",\n") {
                                scratch.removeLast()
                                scratch.removeLast()
                            }
                        }
                        
                        var supportsThenCallArgs = ""
                        var supportsThenUnsafeCallMethod = "unsafeSend"
                        let supportsThenSafeThenCall = "self.safeThen(thenPtr)"
                        if supportsThen {
                            supportsThenUnsafeCallMethod = "unsafeDo"
                            supportsThenCallArgs = ", file__internal, line__internal, column__internal"
                            
                            if parameterLabels.count > minParameterCount || returnType != nil {
                                scratch.append(",\n")
                                scratch.append(parameterNameHeader)
                            }
                            scratch.append("_ file__internal: StaticString = #file,\n")
                            scratch.append(parameterNameHeader + "_ line__internal: UInt64 = #line,\n")
                            scratch.append(parameterNameHeader + "_ column__internal: UInt64 = #column")
                        }
                        
                        scratch.append(") -> Self {\n")
                        
                        if returnType != nil {
                            if hasReturnCallback == true {
                                if disableFatalErrors == false {
                                    scratch.append("        #if DEBUG\n")
                                    scratch.append("        var onlyOnce = true\n")
                                    scratch.append("        #endif\n")
                                }
                            }
                            
                            scratch.append("        return \(supportsThenUnsafeCallMethod) ({ thenPtr in\n")
                            
                            if hasReturnCallback == false {
                                scratch.append("            let result = self._\(name)(")
                            } else {
                                scratch.append("            self._\(name)(")
                            }
                            
                            if let parameters = behavior.function.structure.substructure {
                                var idx = 0
                                for parameter in parameters where parameter.kind == .varParameter && parameter.name != "returnCallback" {
                                    let label = parameterLabels[idx]
                                    if label == "_" {
                                        scratch.append("\(parameter.name!), ")
                                    } else {
                                        scratch.append("\(label): \(parameter.name!), ")
                                    }
                                    idx += 1
                                }
                                if scratch.hasSuffix(", ") {
                                    scratch.removeLast()
                                    scratch.removeLast()
                                }
                            }
                            
                            if hasReturnCallback {
                                scratch.append(") { ")
                                for idx in 0..<returnCallbackParameters.count {
                                    scratch.append("arg\(idx), ")
                                }
                                if scratch.hasSuffix(", ") {
                                    scratch.removeLast()
                                    scratch.removeLast()
                                    scratch.append(" in\n")
                                } else {
                                    scratch.append("\n")
                                }
                                
                                if disableFatalErrors == false {
                                    scratch.append("                #if DEBUG\n")
                                    scratch.append("                guard onlyOnce == true else { fatalError(\"returnCallback called more than once\") }\n")
                                    scratch.append("                onlyOnce = false\n")
                                    scratch.append("                #endif\n")
                                }
                                
                                scratch.append("                sender.unsafeSend { _ in\n")
                                scratch.append("                    callback(")
                                for idx in 0..<returnCallbackParameters.count {
                                    scratch.append("arg\(idx), ")
                                }
                                if scratch.hasSuffix(", ") {
                                    scratch.removeLast()
                                    scratch.removeLast()
                                }
                                scratch.append(")\n")
                                
                                // TODO: tell pony this message is done
                                scratch.append("                    self.unsafeSend { _ in \(supportsThenSafeThenCall) }\n")
                                
                                scratch.append("                }\n")
                                scratch.append("            }\n")
                            } else {
                                scratch.append(")\n")
                                scratch.append("            sender.unsafeSend { _ in\n")
                                scratch.append("                callback(result)\n")
                                scratch.append("                self.unsafeSend { _ in \(supportsThenSafeThenCall) }\n")
                                scratch.append("            }\n")
                            }
                            
                            scratch.append("        }\(supportsThenCallArgs))\n")
                            scratch.append("    }\n")
                        } else {
                            if parameterLabels.count == minParameterCount {
                                scratch.append("        return \(supportsThenUnsafeCallMethod) ({ thenPtr in self._\(name)(); \(supportsThenSafeThenCall) }\(supportsThenCallArgs))\n")
                            } else {
                                scratch.append("        return \(supportsThenUnsafeCallMethod) ({ thenPtr in self._\(name)(")
                                
                                if let parameters = behavior.function.structure.substructure {
                                    var idx = 0
                                    for parameter in parameters where parameter.kind == .varParameter && parameter.name != "returnCallback" {
                                        let label = parameterLabels[idx]
                                        if label == "_" {
                                            scratch.append("\(parameter.name!), ")
                                        } else {
                                            scratch.append("\(label): \(parameter.name!), ")
                                        }
                                        idx += 1
                                    }
                                    if scratch.hasSuffix(", ") {
                                        scratch.removeLast()
                                        scratch.removeLast()
                                    }
                                }
                                scratch.append("); \(supportsThenSafeThenCall) }\(supportsThenCallArgs))\n")
                            }
                            scratch.append("    }\n")
                        }
                    }
                    
                    createBehaviour(false)
                    createBehaviour(true)
                }

                scratch.append("\n}\n")

                if newExtensionString.contains(scratch) == false {
                    newExtensionString.append(scratch)
                }

                if didHaveBehavior {
                    numOfExtensions += 1
                }
            }
        }
    }
    
    
    struct Packet {
        let ast: AST
        let syntax: FileSyntax
        let fileOnly: Bool
    }

    func process(packets: [Packet]) -> [Packet] {
        for packet in packets {
            let ast: AST = packet.ast
            let syntax: FileSyntax = packet.syntax
            let fileOnly: Bool = packet.fileOnly
            
            let disableFatalErrors = syntax.file.contents.contains("// flynn:ignore Reentrant ReturnCallbacks")

            if fileOnly {

                var numOfExtensions: Int = 0
                var fileString = syntax.file.contents
                var fileMarker = "\n// MARK: - Generated by FlynnPluginTool\n"
                if let path = syntax.file.path {
                    fileMarker += "// \(path)\n\n"
                }

                let parts = fileString.components(separatedBy: fileMarker)
                fileString = parts[0]

                // include all imports from the source file, in case they use structures we don't
                // normall have access to
                var importNames = Set<String>()
                syntax.matches(importsRegexString) { (_, _, groups) in
                    importNames.insert(groups[1])
                }
                
                for importName in importNames {
                    guard importName.isEmpty == false else { continue }
                    fileMarker += "#if canImport(\(importName))\n"
                    fileMarker += "import \(importName)\n"
                    fileMarker += "#endif\n"
                }
                
                var newExtensionString = fileMarker

                // 1. run over all actor definitions in this file

                for (_, actorSyntax) in ast.classes.sorted(by: { $0.0 > $1.0 }) {
                    createActorExtensionIfRequired(syntax,
                                                   ast,
                                                   &numOfExtensions,
                                                   &newExtensionString,
                                                   actorSyntax,
                                                   disableFatalErrors)
                }

                for actorSyntax in ast.extensions {
                    // Note: we don't want to do extensions which were
                    // created previously by FlynnPluginTool... but how?
                    createActorExtensionIfRequired(syntax,
                                                   ast,
                                                   &numOfExtensions,
                                                   &newExtensionString,
                                                   actorSyntax,
                                                   disableFatalErrors)
                }
                                
                // NOTE: to support being a SPM build tool, we have two modes:
                // 1. As a build tool, we generate extensons in a new file for all behaviours
                // 2. As a source code formatter, we remove old, in file auto generated code
                if syntax.dependency == false && newExtensionString != fileMarker {
                    if let stringData = newExtensionString.data(using: .utf8),
                       let handle = FileHandle(forWritingAtPath: syntax.outputPath) {
                        handle.seekToEndOfFile()
                        handle.write(stringData)
                        handle.closeFile()
                    }
                }
            }
        }

        return packets
    }
    
}
