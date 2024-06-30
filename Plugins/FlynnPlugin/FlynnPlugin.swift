import Foundation
import PackagePlugin

#if os(Windows)
public let flynnTempPath = "C:/WINDOWS/Temp/"
#else
public let flynnTempPath = "/tmp/"
#endif

/*
var logs: [String] = []

internal func print(_ items: String..., filename: String = #file, function : String = #function, line: Int = #line, separator: String = " ", terminator: String = "\n") {
    let pretty = "\(URL(fileURLWithPath: filename).lastPathComponent) [#\(line)] \(function)\n\t-> "
    let output = items.map { "\($0)" }.joined(separator: separator)
    Swift.print(pretty+output, terminator: terminator)
    logs.append(output)
}

internal func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let output = items.map { "\($0)" }.joined(separator: separator)
    Swift.print(output, terminator: terminator)
    logs.append(output)
}

internal func clearLogs() {
    try? FileManager.default.removeItem(atPath: "\(flynnTempPath)/FlynnPlugin.log")
}

internal func exportLogs() {
    let logString = logs.joined(separator: "\n")
    try? logString.write(toFile: "\(flynnTempPath)/FlynnPlugin.log", atomically: false, encoding: .utf8)
}
*/

func binaryTool(context: PluginContext, named toolName: String) -> String {
    var osName = "focal"
    
    #if os(Windows)
    osName = "windows"
    #else
    if let osFile = try? String(contentsOfFile: "/etc/os-release") {
        if osFile.contains("Amazon Linux") {
            osName = "amazonlinux2"
        }
        if osFile.contains("Fedora Linux 37") {
            osName = "fedora37"
        }
        if osFile.contains("Fedora Linux 38") {
            osName = "fedora38"
        }
    }
    #endif
    
    var swiftVersions: [String] = []
#if swift(>=5.9.2)
    swiftVersions.append("592")
#endif
#if swift(>=5.8.0)
    swiftVersions.append("580")
#endif
#if swift(>=5.7.3)
    swiftVersions.append("573")
#endif
#if swift(>=5.7.1)
    swiftVersions.append("571")
#endif
    
    // Find the most recent version of swift we support and return that
    for swiftVersion in swiftVersions {
        let toolName = "\(toolName)-\(osName)-\(swiftVersion)"
        if let _ = try? context.tool(named: toolName) {
            return toolName
        }
    }

    return "\(toolName)-\(osName)-\(swiftVersions.first!)"
}

@main struct FlynnPlugin: BuildToolPlugin {
    
    fileprivate func gatherSwiftInputFiles(targets: [Target],
                                           inputFiles: inout [PackagePlugin.Path]) {
        
        for target in targets {
            
            var hasFlynnDependency = target.name == "Flynn"
            for dependency in target.dependencies {
                switch dependency {
                case .target(let target):
                    if target.name == "Flynn" {
                        hasFlynnDependency = true
                    }
                    break
                case .product(let product):
                    if product.name == "Flynn" {
                        hasFlynnDependency = true
                    }
                    break
                default:
                    break
                }
            }
            
            guard hasFlynnDependency else { continue }
            
            var directoryPath = target.directory.string
            #if os(Windows)
            directoryPath = "C:" + directoryPath
            #endif
            
            let url = URL(fileURLWithPath: directoryPath)
            if let enumerator = FileManager.default.enumerator(at: url,
                                                               includingPropertiesForKeys: [.isRegularFileKey],
                                                               options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                for case let fileURL as URL in enumerator {
                    do {
                        let fileAttributes = try fileURL.resourceValues(forKeys:[.isRegularFileKey])
                        if fileAttributes.isRegularFile == true && fileURL.pathExtension == "swift" {
                            inputFiles.append(PackagePlugin.Path(fileURL.path))
                        }
                    } catch { print(error, fileURL) }
                }
            }
        }
    }
    
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        
        guard let target = target as? SwiftSourceModuleTarget else {
            return []
        }
        
        let toolName = "FlynnPluginTool"
        let binaryToolName = binaryTool(context: context, named: toolName)
        guard let tool = (try? context.tool(named: binaryToolName)) ?? (try? context.tool(named: toolName)) else {
            fatalError("FlynnPlugin unable to load \(binaryToolName)")
        }
        
        // Find all .swift files in our target and all of our target's dependencies, add them as input files
        var rootFiles: [PackagePlugin.Path] = []
        var dependencyFiles: [PackagePlugin.Path] = []
        
        gatherSwiftInputFiles(targets: [target],
                              inputFiles: &rootFiles)
        gatherSwiftInputFiles(targets: target.recursiveTargetDependencies,
                              inputFiles: &dependencyFiles)
        
        let allInputFiles = rootFiles + dependencyFiles
        
        var inputFilesFilePath = context.pluginWorkDirectory.string + "/inputFiles.txt"
        var inputFilesString = ""
                
        for file in rootFiles {
            inputFilesString.append("\(file)\n")
        }
        for file in dependencyFiles {
            inputFilesString.append("+\(file)\n")
        }

        try! inputFilesString.write(toFile: inputFilesFilePath, atomically: false, encoding: .utf8)
        
        // let outputFilePath = context.pluginWorkDirectory.string + "/" + UUID().uuidString + ".swift"
        var outputFilePath = context.pluginWorkDirectory.string + "/FlynnPlugin.swift"
        
        #if os(Windows)
        inputFilesFilePath = "C:" + inputFilesFilePath
        outputFilePath = "C:" + outputFilePath
        #endif
        
        return [
            .buildCommand(
                displayName: "Flynn Plugin - generating behaviours...",
                executable: tool.path,
                arguments: [
                    inputFilesFilePath,
                    outputFilePath
                ],
                inputFiles: allInputFiles,
                outputFiles: [
                    PackagePlugin.Path(outputFilePath)
                ]
            )
        ]
    }
}
