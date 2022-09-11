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

    // MARK: - REMOTE ACTOR
    private func createRemoteActorExtensionIfRequired(_ syntax: FileSyntax,
                                                      _ ast: AST,
                                                      _ numOfExtensions: inout Int,
                                                      _ newExtensionString: inout String,
                                                      _ actorSyntax: FileSyntax,
                                                      _ firstTime: Bool) -> Bool {
        if  actorSyntax.file == syntax.file {
            let fullActorName = AST.getFullName(syntax,
                                                actorSyntax.ancestry,
                                                actorSyntax)
            guard ast.isRemoteActor(fullActorName) else { return false }

            let (internals, _) = ast.getBehaviorsForActor(actorSyntax)

            if internals.count >= 0 {
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
                
                let isBinaryCodable: (FileSyntax) -> (Bool) = {
                    let binaryCodableMarkup = $0.markup("codable")
                    if binaryCodableMarkup.count > 0 &&
                        binaryCodableMarkup[0].1.trimmingCharacters(in: .whitespacesAndNewlines) == "binary" {
                        return true
                    }
                    return false
                }

                // 0. Create all Codable structs for message serializations (only if it has arguments)
                for behavior in internals where behavior.function.file.path == syntax.file.path && behavior.function.structure.name != nil {
                    let binaryCodable = isBinaryCodable(behavior.function)
                                        
                    checkParametersForRemoteCallback(behavior)

                    let (name, parameterLabels) = ast.parseFunctionDefinition(behavior.function.structure)
                    var returnType = behavior.function.structure.typename
                    if returnType == "Void" {
                        returnType = nil
                    }
                    if returnType == nil && returnCallbackParameters.count > 0 {
                        returnType = returnCallbackParameters[0]
                    }
                    
                    let appendEncoderLineSingle: (String,String) -> Void = { name, type in
                        if type == "Bool" {
                            scratch.append("            try container.encode(UInt8(\(name) ? 1 : 0))\n")
                        } else if type == "Data" {
                            scratch.append("            try container.encode(UInt32(\(name).count))\n")
                            scratch.append("            try container.encode(sequence: \(name))\n")
                        } else if type == "String" {
                            scratch.append("            try container.encode(\(name), encoding: .utf8, terminator: 0)\n")
                        } else if type == "String?" {
                            scratch.append("            try container.encode(\(name) ?? \"FLYNN_NULL\", encoding: .utf8, terminator: 0)\n")
                        } else {
                            scratch.append("            try container.encode(\(name))\n")
                        }
                    }
                    
                    let appendEncoderLineArray: (String,String) -> Void = { name, type in
                        if type == "Bool" {
                            scratch.append("                try container.encode(UInt8(\(name) ? 1 : 0))\n")
                        } else if type == "Data" {
                            scratch.append("                try container.encode(UInt32(\(name).count))\n")
                            scratch.append("                try container.encode(sequence: \(name))\n")
                        } else if type == "String" {
                            scratch.append("                try container.encode(\(name), encoding: .utf8, terminator: 0)\n")
                        } else if type == "String?" {
                            scratch.append("                try container.encode(\(name) ?? \"FLYNN_NULL\", encoding: .utf8, terminator: 0)\n")
                        } else {
                            scratch.append("                try container.encode(\(name))\n")
                        }
                    }
                    
                    let appendEncoderLine: (String,String) -> Void = { name, type in
                        if type.hasPrefix("[") && type.hasSuffix("]") {
                            let single = type.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                            if single.hasSuffix("?") {
                                scratch.append("            try container.encode(UInt32(\(name).count ?? 0))\n")
                            } else {
                                scratch.append("            try container.encode(UInt32(\(name).count))\n")
                            }
                            scratch.append("            for item in \(name) {\n")
                            appendEncoderLineArray("item", single)
                            scratch.append("            }\n")
                            return
                        }
                        
                        appendEncoderLineSingle(name, type)
                    }
                    
                    let appendDecoderLineSingle: (String,String) -> Void = { name, type in
                        if type == "Bool" {
                            scratch.append("            \(name) = try container.decode(UInt8.self) == 0 ? false : true\n")
                        } else if type == "Data" {
                            scratch.append("            let \(name)Count = Int(try container.decode(UInt32.self))\n")
                            scratch.append("            \(name) = try container.decode(length: \(name)Count)\n")
                        } else if type == "String" {
                            scratch.append("            \(name) = try container.decodeString(encoding: .utf8, terminator: 0)\n")
                        } else if type == "String?" {
                            scratch.append("            let \(name)Check = try container.decodeString(encoding: .utf8, terminator: 0)\n")
                            scratch.append("            \(name) = \(name)Check == \"FLYNN_NULL\" ? nil : \(name)Check\n")
                        } else {
                            scratch.append("            \(name) = try container.decode(\(type).self)\n")
                        }
                    }
                    
                    let appendDecoderLineArray: (String,String) -> Void = { name, type in
                        if type == "Bool" {
                            scratch.append("                \(name)Array.append(try container.decode(UInt8.self) == 0 ? false : true)\n")
                        } else if type == "Data" {
                            scratch.append("                let \(name)Count = Int(try container.decode(UInt32.self))\n")
                            scratch.append("                \(name)Array.append(try container.decode(length: \(name)Count))\n")
                        } else if type == "String" {
                            scratch.append("                \(name)Array.append(try container.decodeString(encoding: .utf8, terminator: 0))\n")
                        } else if type == "String?" {
                            scratch.append("                \(name)Item = try container.decodeString(encoding: .utf8, terminator: 0)\n")
                            scratch.append("                if \(name)Item == \"FLYNN_NULL\" { \(name)Item = nil }\n")
                            scratch.append("                \(name)Array.append(\(name)Item)\n")
                        } else {
                            scratch.append("                \(name)Array.append(try container.decode(\(type).self))\n")
                        }
                    }
                    
                    let appendDecoderLine: (String,String) -> Void = { name, type in
                        if type.hasPrefix("[") && type.hasSuffix("]") {
                            let single = type.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                            scratch.append("            let \(name)Count: Int = Int(try container.decode(UInt32.self))\n")
                            if single.hasSuffix("?") {
                                scratch.append("            var \(name)Item: \(type)? = nil\n")
                            }
                            scratch.append("            var \(name)Array: \(type) = []\n")
                            scratch.append("            for _ in 0..<\(name)Count {\n")
                            appendDecoderLineArray(name, single)
                            scratch.append("            }\n")
                            scratch.append("            \(name) = \(name)Array\n")
                            return
                        }
                        appendDecoderLineSingle(name, type)
                    }

                    if let returnType = returnType {
                        
                        if binaryCodable {
                            scratch.append("    struct \(codableName(name))Response: BinaryEncodable, BinaryDecodable {\n")
                        } else {
                            scratch.append("    struct \(codableName(name))Response: Codable {\n")
                        }

                        // if the returnType is a tuple
                        if returnType.hasPrefix("(") {
                            let (parts, _) = ast.parseTupleType(returnType)
                            var idx = 0
                            for part in parts {
                                scratch.append("        let response\(idx): \(part)\n")
                                idx += 1
                            }
                        } else if returnCallbackParameters.count > 0 {
                            var idx = 0
                            for part in returnCallbackParameters {
                                scratch.append("        let response\(idx): \(part)\n")
                                idx += 1
                            }
                        } else {
                            scratch.append("        let response: \(returnType)\n")
                        }
                        
                        if binaryCodable {
                            // init
                            scratch.append("\n")
                            if returnType.hasPrefix("(") || returnCallbackParameters.count > 0 {
                                var parts = returnCallbackParameters
                                if returnType.hasPrefix("(") {
                                    parts = ast.parseTupleType(returnType).0
                                }
                                var idx = 0
                                scratch.append("        init(")
                                for part in parts {
                                    if idx > 0 {
                                        scratch.append("             ")
                                    }
                                    scratch.append("response\(idx): \(part),\n")
                                    idx += 1
                                }
                                scratch.removeLast()
                                scratch.removeLast()
                                scratch.append(") {\n")
                                idx = 0
                                for _ in parts {
                                    scratch.append("             self.response\(idx) = response\(idx)\n")
                                    idx += 1
                                }
                                scratch.append("        }\n")
                            } else {
                                scratch.append("        init(response: \(returnType)) {\n")
                                scratch.append("            self.response = response\n")
                                scratch.append("        }\n")
                            }
                            
                            
                            // BinaryEncoder
                            scratch.append("\n")
                            if returnType.hasPrefix("(") || returnCallbackParameters.count > 0 {
                                var parts = returnCallbackParameters
                                if returnType.hasPrefix("(") {
                                    parts = ast.parseTupleType(returnType).0
                                }
                                var idx = 0
                                scratch.append("        func encode(to encoder: BinaryEncoder) throws {\n")
                                scratch.append("            var container = encoder.container()\n")
                                for part in parts {
                                    appendEncoderLine("response\(idx)", part)
                                    idx += 1
                                }
                                scratch.append("        }\n")
                            } else {
                                scratch.append("        func encode(to encoder: BinaryEncoder) throws {\n")
                                scratch.append("            var container = encoder.container()\n")
                                appendEncoderLine("response", returnType)
                                scratch.append("        }\n")
                            }
                            
                            // BinaryDecoder
                            scratch.append("\n")
                            if returnType.hasPrefix("(") || returnCallbackParameters.count > 0 {
                                var parts = returnCallbackParameters
                                if returnType.hasPrefix("(") {
                                    parts = ast.parseTupleType(returnType).0
                                }
                                var idx = 0
                                scratch.append("        init(from decoder: BinaryDecoder) throws {\n")
                                scratch.append("            var container = decoder.container(maxLength: nil)\n")
                                for part in parts {
                                    appendDecoderLine("response\(idx)", part)
                                    idx += 1
                                }
                                scratch.append("        }\n")
                            } else {
                                scratch.append("        init(from decoder: BinaryDecoder) throws {\n")
                                scratch.append("            var container = decoder.container(maxLength: nil)\n")
                                appendDecoderLine("response", returnType)
                                scratch.append("        }\n")
                            }
                        }

                        
                        scratch.append("    }\n")
                    }

                    if parameterLabels.count > minParameterCount {
                        if binaryCodable {
                            scratch.append("    struct \(codableName(name))Request: BinaryEncodable, BinaryDecodable {\n")
                        } else {
                            scratch.append("    struct \(codableName(name))Request: Codable {\n")
                        }
                        if let parameters = behavior.function.structure.substructure {
                            var idx = 0
                            for parameter in parameters where parameter.kind == .varParameter {
                                if  let typename = parameter.typename {
                                    if parameter.name != "returnCallback" {
                                        scratch.append("        let arg\(idx): \(typename)\n")
                                        idx += 1
                                    }
                                }
                            }
                            
                            if binaryCodable {
                                // init
                                scratch.append("\n")
                                scratch.append("        init(")
                                idx = 0
                                for parameter in parameters where parameter.kind == .varParameter {
                                    if  let typename = parameter.typename {
                                        if parameter.name != "returnCallback" {
                                            if idx > 0 {
                                                scratch.append("             ")
                                            }
                                            scratch.append("arg\(idx): \(typename),\n")
                                            idx += 1
                                        }
                                    }
                                }
                                scratch.removeLast()
                                scratch.removeLast()
                                scratch.append(") {\n")
                                idx = 0
                                for parameter in parameters where parameter.kind == .varParameter {
                                    if parameter.name != "returnCallback" {
                                        scratch.append("            self.arg\(idx) = arg\(idx)\n")
                                        idx += 1
                                    }
                                }
                                scratch.append("        }\n")
                                
                                // BinaryEncoder
                                scratch.append("\n")
                                scratch.append("        func encode(to encoder: BinaryEncoder) throws {\n")
                                scratch.append("            var container = encoder.container()\n")
                                idx = 0
                                for parameter in parameters where parameter.kind == .varParameter {
                                    if let typename = parameter.typename {
                                        if parameter.name != "returnCallback" {
                                            appendEncoderLine("arg\(idx)", typename)
                                            idx += 1
                                        }
                                    }
                                }
                                scratch.append("        }\n")
                                
                                // BinaryDecoder
                                scratch.append("\n")
                                scratch.append("        init(from decoder: BinaryDecoder) throws {\n")
                                scratch.append("            var container = decoder.container(maxLength: nil)\n")
                                idx = 0
                                for parameter in parameters where parameter.kind == .varParameter {
                                    if let typename = parameter.typename {
                                        if parameter.name != "returnCallback" {
                                            appendDecoderLine("arg\(idx)", typename)
                                            idx += 1
                                        }
                                    }
                                }
                                scratch.append("        }\n")
                            }
                            
                        }
                        scratch.append("    }\n")
                    }
                }

                if internals.count > 0 { scratch.append("\n") }

                // 1. Create all external behaviors (two types, with and without return values)

                for behavior in internals where behavior.function.file.path == syntax.file.path && behavior.function.structure.name != nil {
                    let binaryCodable = isBinaryCodable(behavior.function)
                    
                    checkParametersForRemoteCallback(behavior)

                    let (name, parameterLabels) = ast.parseFunctionDefinition(behavior.function.structure)
                    let namespaces = String(repeating: " ", count: name.count)
                    
                    var returnType = behavior.function.structure.typename
                    if returnType == "Void" {
                        returnType = nil
                    }
                    if returnType == nil && returnCallbackParameters.count > 0 {
                        returnType = returnCallbackParameters[0]
                    }

                    if parameterLabels.count == minParameterCount {
                        if returnCallbackParameters.count > 0 {
                            if behavior.function.structure.has(attribute: .inlinable) {
                                scratch.append("    @inlinable\n")
                            }
                            scratch.append("    @discardableResult\n")
                            scratch.append("    public func \(name)(_ sender: Actor,\n")
                            scratch.append("                \(namespaces) _ error: @escaping () -> Void,\n")
                            scratch.append("                \(namespaces) _ callback: @escaping (")
                            for part in returnCallbackParameters {
                                scratch.append("\(part), ")
                            }
                            if scratch.hasSuffix(", ") {
                                scratch.removeLast()
                                scratch.removeLast()
                            }
                            scratch.append(") -> Void) -> Self {\n")
                            
                            scratch.append("        unsafeSendToRemote(\"\(fullActorName)\", \"\(name)\", Data(), sender, error) {\n")
                            scratch.append("            // swiftlint:disable:next force_try\n")
                            if binaryCodable {
                                scratch.append("            let response = (try! BinaryDataDecoder().decode(\(codableName(name))Response.self, from: $0))\n")
                            } else {
                                scratch.append("            let response = (try! JSONDecoder().decode(\(codableName(name))Response.self, from: $0))\n")
                            }
                            scratch.append("            callback(\n")
                            for idx in 0..<returnCallbackParameters.count {
                                scratch.append("                response.response\(idx),\n")
                            }
                            if scratch.hasSuffix(",\n") {
                                scratch.removeLast()
                                scratch.removeLast()
                            }
                            scratch.append("\n")
                            scratch.append("            )\n")
                            scratch.append("        }\n")
                            scratch.append("        return self\n")
                            scratch.append("    }\n")
                        } else if let returnType = returnType {
                            if behavior.function.structure.has(attribute: .inlinable) {
                                scratch.append("    @inlinable\n")
                            }
                            scratch.append("    @discardableResult\n")
                            scratch.append("    public func \(name)(_ sender: Actor,\n")
                            scratch.append("                \(namespaces) _ error: @escaping () -> Void,\n")
                            scratch.append("                \(namespaces) _ callback: @escaping (\(returnType)) -> Void) -> Self {\n")
                            scratch.append("        unsafeSendToRemote(\"\(fullActorName)\", \"\(name)\", Data(), sender, error) {\n")
                            scratch.append("            callback(\n")
                            scratch.append("                // swiftlint:disable:next force_try\n")
                            if binaryCodable {
                                scratch.append("                (try! BinaryDataDecoder().decode(\(codableName(name))Response.self, from: $0)).response\n")
                            } else {
                                scratch.append("                (try! JSONDecoder().decode(\(codableName(name))Response.self, from: $0)).response\n")
                            }
                            scratch.append("            )\n")
                            scratch.append("        }\n")
                            scratch.append("        return self\n")
                            scratch.append("    }\n")
                        } else {
                            if behavior.function.structure.has(attribute: .inlinable) {
                                scratch.append("    @inlinable\n")
                            }
                            scratch.append("    @discardableResult\n")
                            scratch.append("    public func \(name)() -> Self {\n")
                            scratch.append("        unsafeSendToRemote(\"\(fullActorName)\", \"\(name)\", Data(), nil, nil, nil)\n")
                            scratch.append("        return self\n")
                            scratch.append("    }\n")
                        }
                    } else {

                        if behavior.function.structure.has(attribute: .inlinable) {
                            scratch.append("    @inlinable\n")
                        }
                        scratch.append("    @discardableResult\n")
                        let functionNameHeader = "    public func \(name)("
                        scratch.append(functionNameHeader)
                        let parameterNameHeader = String(repeating: " ", count: functionNameHeader.count)
                        if let parameters = behavior.function.structure.substructure {
                            var idx = 0
                            for parameter in parameters where parameter.kind == .varParameter && parameter.name != "returnCallback" {
                                let label = parameterLabels[idx]

                                if let typename = parameter.typename,
                                    let name = parameter.name {
                                    let typename = AST.getFullName(syntax, typename)
                                    if idx != 0 {
                                        scratch.append(parameterNameHeader)
                                    }
                                    if label == name {
                                        scratch.append("\(name): \(typename),\n")
                                    } else {
                                        scratch.append("\(label) \(name): \(typename),\n")
                                    }
                                }
                                idx += 1
                            }
                        }

                        if returnCallbackParameters.count > 0 {
                            scratch.append("\(parameterNameHeader)_ sender: Actor,\n")
                            scratch.append("\(parameterNameHeader)_ error: @escaping () -> Void,\n")
                            scratch.append("\(parameterNameHeader)_ callback: @escaping (\(returnCallbackParameters.joined(separator: ", "))) -> Void,\n")
                        } else if let returnType = returnType {
                            scratch.append("\(parameterNameHeader)_ sender: Actor,\n")
                            scratch.append("\(parameterNameHeader)_ error: @escaping () -> Void,\n")
                            scratch.append("\(parameterNameHeader)_ callback: @escaping (\(returnType)) -> Void,\n")
                        }
                        

                        if scratch.hasSuffix(",\n") {
                            scratch.removeLast()
                            scratch.removeLast()
                        }
                        scratch.append(") -> Self {\n")

                        scratch.append("        let msg = \(codableName(name))Request(")
                        if let parameters = behavior.function.structure.substructure {
                            var idx = 0
                            for parameter in parameters where parameter.kind == .varParameter {
                                if let name = parameter.name {
                                    if parameter.name != "returnCallback" {
                                        scratch.append("arg\(idx): \(name), ")
                                        idx += 1
                                    }
                                }
                            }
                            if scratch.hasSuffix(", ") {
                                scratch.removeLast()
                                scratch.removeLast()
                            }
                        }
                        scratch.append(")\n")

                        scratch.append("        // swiftlint:disable:next force_try\n")
                        if binaryCodable {
                            scratch.append("        let data = try! BinaryDataEncoder().encode(msg)\n")
                        } else {
                            scratch.append("        let data = try! JSONEncoder().encode(msg)\n")
                        }
                        if returnType != nil {
                            scratch.append("        unsafeSendToRemote(\"\(fullActorName)\", \"\(name)\", data, sender, error) {\n")

                            if let returnType = returnType, returnType.hasPrefix("(") {
                                let (parts, _) = ast.parseTupleType(returnType)
                                var idx = 0

                                scratch.append("            // swiftlint:disable:next force_try\n")
                                if binaryCodable {
                                    scratch.append("            let msg = try! BinaryDataDecoder().decode(\(codableName(name))Response.self, from: $0)\n")
                                } else {
                                    scratch.append("            let msg = try! JSONDecoder().decode(\(codableName(name))Response.self, from: $0)\n")
                                }
                                scratch.append("            callback((\n")
                                for _ in parts {
                                    scratch.append("                msg.response\(idx),\n")
                                    idx += 1
                                }
                                if scratch.hasSuffix(",\n") {
                                    scratch.removeLast(2)
                                    scratch.append("\n")
                                }
                                scratch.append("            ))\n")

                            } else if returnCallbackParameters.count > 0 {
                                var idx = 0

                                scratch.append("            // swiftlint:disable:next force_try\n")
                                if binaryCodable {
                                    scratch.append("            let msg = try! BinaryDataDecoder().decode(\(codableName(name))Response.self, from: $0)\n")
                                } else {
                                    scratch.append("            let msg = try! JSONDecoder().decode(\(codableName(name))Response.self, from: $0)\n")
                                }
                                scratch.append("            callback(\n")
                                for _ in returnCallbackParameters {
                                    scratch.append("                msg.response\(idx),\n")
                                    idx += 1
                                }
                                if scratch.hasSuffix(",\n") {
                                    scratch.removeLast(2)
                                    scratch.append("\n")
                                }
                                scratch.append("            )\n")
                                
                            } else {
                                scratch.append("            callback(\n")
                                scratch.append("                // swiftlint:disable:next force_try\n")
                                if binaryCodable {
                                    scratch.append("                (try! BinaryDataDecoder().decode(\(codableName(name))Response.self, from: $0).response)\n")
                                } else {
                                    scratch.append("                (try! JSONDecoder().decode(\(codableName(name))Response.self, from: $0).response)\n")
                                }
                                scratch.append("            )\n")
                            }

                            scratch.append("        }\n")
                        } else {
                            scratch.append("        unsafeSendToRemote(\"\(fullActorName)\", \"\(name)\", data, nil, nil, nil)\n")
                        }
                        scratch.append("        return self\n")
                        scratch.append("    }\n")

                    }
                }

                if internals.count > 0 { scratch.append("\n") }

                // 2. Create unsafeRegisterAllBehaviors()

                scratch.append("    public func unsafeRegisterAllBehaviors() {\n")

                for behavior in internals where behavior.function.file.path == syntax.file.path && behavior.function.structure.name != nil {
                    let binaryCodable = isBinaryCodable(behavior.function)
                    
                    checkParametersForRemoteCallback(behavior)

                    let (name, parameterLabels) = ast.parseFunctionDefinition(behavior.function.structure)
                    var returnType = behavior.function.structure.typename
                    if returnType == "Void" {
                        returnType = nil
                    }
                    if returnType == nil && returnCallbackParameters.count > 0 {
                        returnType = returnCallbackParameters[0]
                    }

                    if hasReturnCallback {

                        if parameterLabels.count > minParameterCount {
                            scratch.append("        safeRegisterDelayedRemoteBehavior(\"\(name)\") { [unowned self] (data, callback) in\n")
                            scratch.append("            // swiftlint:disable:next force_try\n")
                            if binaryCodable {
                                scratch.append("            let msg = try! BinaryDataDecoder().decode(\(codableName(name))Request.self, from: data)\n")
                            } else {
                                scratch.append("            let msg = try! JSONDecoder().decode(\(codableName(name))Request.self, from: data)\n")
                            }
                            
                            scratch.append("            #if DEBUG\n")
                            scratch.append("            var onlyOnce = true\n")
                            scratch.append("            #endif\n")

                            scratch.append("            self._\(name)(")
                            if let parameters = behavior.function.structure.substructure {
                                var idx = 0
                                for parameter in parameters where parameter.kind == .varParameter && parameter.name != "returnCallback" {
                                    scratch.append("msg.arg\(idx), ")
                                    idx += 1
                                }
                            }

                            if scratch.hasSuffix(", ") {
                                scratch.removeLast()
                                scratch.removeLast()
                            }

                            scratch.append(") {\n")
                            
                            scratch.append("                #if DEBUG\n")
                            scratch.append("                guard onlyOnce == true else { fatalError(\"returnCallback called more than once\") }\n")
                            scratch.append("                onlyOnce = false\n")
                            scratch.append("                #endif\n")

                            if returnCallbackParameters.count > 0 {
                                scratch.append("                callback(\n")
                                scratch.append("                    // swiftlint:disable:next force_try\n")
                                if binaryCodable {
                                    scratch.append("                    try! BinaryDataEncoder().encode(\n")
                                } else {
                                    scratch.append("                    try! JSONEncoder().encode(\n")
                                }
                                scratch.append("                        \(codableName(name))Response(\n")
                                for idx in 0..<returnCallbackParameters.count {
                                    scratch.append("                            response\(idx): $\(idx),\n")
                                }
                                if scratch.hasSuffix(",\n") {
                                    scratch.removeLast()
                                    scratch.removeLast()
                                }
                                scratch.append("\n                        )\n")
                                scratch.append("                    )\n")
                                scratch.append("                )\n")
                            } else {
                                scratch.append("                callback(Data())\n")
                            }
                            scratch.append("            }\n")

                            scratch.append("        }\n")
                        } else {
                            scratch.append("        safeRegisterDelayedRemoteBehavior(\"\(name)\") { [unowned self] (_, callback) in\n")

                            scratch.append("            #if DEBUG\n")
                            scratch.append("            var onlyOnce = true\n")
                            scratch.append("            #endif\n")
                            
                            if returnCallbackParameters.count > 1 {
                                var idx = 0
                                scratch.append("            self._\(name) { (")
                                for part in returnCallbackParameters {
                                    scratch.append("returnValue\(idx): \(part)),\n")
                                    idx += 1
                                }
                                if scratch.hasSuffix(",\n") {
                                    scratch.removeLast()
                                    scratch.removeLast()
                                }
                                scratch.append(") in\n")
                                
                            } else {
                                scratch.append("            self._\(name) {\n")
                            }
                            
                            scratch.append("                #if DEBUG\n")
                            scratch.append("                guard onlyOnce == true else { fatalError(\"returnCallback called more than once\") }\n")
                            scratch.append("                onlyOnce = false\n")
                            scratch.append("                #endif\n")

                            if returnCallbackParameters.count > 0 {
                                scratch.append("                callback(\n")
                                scratch.append("                    // swiftlint:disable:next force_try\n")
                                if binaryCodable {
                                    scratch.append("                    try! BinaryDataEncoder().encode(\n")
                                } else {
                                    scratch.append("                    try! JSONEncoder().encode(\n")
                                }
                                scratch.append("                        \(codableName(name))Response(\n")
                                for idx in 0..<returnCallbackParameters.count {
                                    scratch.append("                            response\(idx): $\(idx),\n")
                                }
                                if scratch.hasSuffix(",\n") {
                                    scratch.removeLast()
                                    scratch.removeLast()
                                }
                                scratch.append("\n                        )\n")
                                scratch.append("                    )\n")
                                scratch.append("                )\n")
                            } else {
                                scratch.append("                callback(Data())\n")
                            }
                            scratch.append("            }\n")
                            scratch.append("        }\n")
                        }

                    } else {

                        if parameterLabels.count > minParameterCount {
                            scratch.append("        safeRegisterRemoteBehavior(\"\(name)\") { [unowned self] (data) in\n")
                            scratch.append("            // swiftlint:disable:next force_try\n")
                            if binaryCodable {
                                scratch.append("            let msg = try! BinaryDataDecoder().decode(\(codableName(name))Request.self, from: data)\n")
                            } else {
                                scratch.append("            let msg = try! JSONDecoder().decode(\(codableName(name))Request.self, from: data)\n")
                            }

                            if returnType != nil {
                                scratch.append("            let response = self._\(name)(")
                            } else {
                                scratch.append("            self._\(name)(")
                            }
                            if let parameters = behavior.function.structure.substructure {
                                var idx = 0
                                for parameter in parameters where parameter.kind == .varParameter && parameter.name != "returnCallback" {
                                    scratch.append("msg.arg\(idx), ")
                                    idx += 1
                                }
                            }
                            if scratch.hasSuffix(", ") {
                                scratch.removeLast()
                                scratch.removeLast()
                            }
                            scratch.append(")\n")

                            if returnType != nil {
                                if let returnType = returnType, returnType.hasPrefix("(") {
                                    let (parts, _) = ast.parseTupleType(returnType)
                                    var idx = 0
                                    scratch.append("            let boxedResponse = \(codableName(name))Response(\n")
                                    for _ in parts {
                                        scratch.append("                response\(idx): response.\(idx),\n")
                                        idx += 1
                                    }
                                    if scratch.hasSuffix(",\n") {
                                        scratch.removeLast(2)
                                        scratch.append("\n")
                                    }
                                    scratch.append("            )\n")
                                    scratch.append("            // swiftlint:disable:next force_try\n")
                                    if binaryCodable {
                                        scratch.append("            return try! BinaryDataEncoder().encode(boxedResponse)\n")
                                    } else {
                                        scratch.append("            return try! JSONEncoder().encode(boxedResponse)\n")
                                    }
                                } else {
                                    scratch.append("            let boxedResponse = \(codableName(name))Response(response: response)\n")
                                    scratch.append("            // swiftlint:disable:next force_try\n")
                                    if binaryCodable {
                                        scratch.append("            return try! BinaryDataEncoder().encode(boxedResponse)\n")
                                    } else {
                                        scratch.append("            return try! JSONEncoder().encode(boxedResponse)\n")
                                    }
                                }
                            } else {
                                scratch.append("            return nil\n")
                            }

                            scratch.append("        }\n")
                        } else {
                            scratch.append("        safeRegisterRemoteBehavior(\"\(name)\") { [unowned self] (_) in\n")
                            if returnType != nil {
                                scratch.append("            // swiftlint:disable:next force_try\n")
                                if binaryCodable {
                                    scratch.append("            return try! BinaryDataEncoder().encode(\n")
                                } else {
                                    scratch.append("            return try! JSONEncoder().encode(\n")
                                }
                                scratch.append("                \(codableName(name))Response(response: self._\(name)()))\n")
                            } else {
                                scratch.append("            self._\(name)()\n")
                                scratch.append("            return nil\n")
                            }
                            scratch.append("        }\n")
                        }

                    }
                }
                if internals.count == 0 {
                    scratch.append("\n")
                }

                scratch.append("    }\n")

                scratch.append("}\n")

                if newExtensionString.contains(scratch) == false {
                    newExtensionString.append(scratch)
                }

                numOfExtensions += 1
            }
            return true
        }
        return false
    }

    // MARK: - ACTOR
    private func createActorExtensionIfRequired(_ syntax: FileSyntax,
                                                _ ast: AST,
                                                _ numOfExtensions: inout Int,
                                                _ newExtensionString: inout String,
                                                _ actorSyntax: FileSyntax) {
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

                    // 2. the names and type of the parameters are in the substructures
                    if behavior.function.structure.has(attribute: .inlinable) {
                        scratch.append("    @inlinable\n")
                    }
                    scratch.append("    @discardableResult\n")
                    let functionNameHeader = "    public func \(name)("
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
                    scratch.append(") -> Self {\n")

                    if returnType != nil {
                        if hasReturnCallback == true {
                            scratch.append("        #if DEBUG\n")
                            scratch.append("        var onlyOnce = true\n")
                            scratch.append("        #endif\n")
                        }
                        
                        scratch.append("        return unsafeSend { thenPtr in\n")

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
                            
                            scratch.append("                #if DEBUG\n")
                            scratch.append("                guard onlyOnce == true else { fatalError(\"returnCallback called more than once\") }\n")
                            scratch.append("                onlyOnce = false\n")
                            scratch.append("                #endif\n")

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
                            scratch.append("                    self.unsafeSend { _ in self.safeThen(thenPtr) }\n")
                            
                            scratch.append("                }\n")
                            scratch.append("            }\n")
                        } else {
                            scratch.append(")\n")
                            scratch.append("            sender.unsafeSend { _ in\n")
                            scratch.append("                callback(result)\n")
                            scratch.append("                self.unsafeSend { _ in self.safeThen(thenPtr) }\n")
                            scratch.append("            }\n")
                        }

                        scratch.append("        }\n")
                        scratch.append("    }\n")
                    } else {
                        if parameterLabels.count == minParameterCount {
                            scratch.append("        return unsafeSend { thenPtr in self._\(name)() }\n")
                        } else {
                            scratch.append("        return unsafeSend { thenPtr in self._\(name)(")

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
                            scratch.append(") }\n")
                        }
                        scratch.append("    }\n")
                    }
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
                                                   actorSyntax)
                }

                for actorSyntax in ast.extensions {
                    // Note: we don't want to do extensions which were
                    // created previously by FlynnPluginTool... but how?
                    createActorExtensionIfRequired(syntax,
                                                   ast,
                                                   &numOfExtensions,
                                                   &newExtensionString,
                                                   actorSyntax)
                }

                var first = true
                for (_, actorSyntax) in ast.classes.sorted(by: { $0.0 > $1.0 }) {
                    if createRemoteActorExtensionIfRequired(syntax,
                                                            ast,
                                                            &numOfExtensions,
                                                            &newExtensionString,
                                                            actorSyntax,
                                                            first) {
                        first = false
                    }
                }

                for actorSyntax in ast.extensions {
                    // Note: we don't want to do extensions which were
                    // created previously by FlynnPluginTool... but how?
                    if createRemoteActorExtensionIfRequired(syntax,
                                                            ast,
                                                            &numOfExtensions,
                                                            &newExtensionString,
                                                            actorSyntax,
                                                            first) {
                        first = false
                    }
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
