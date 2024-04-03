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
        
        // Note: We want to load the right pre-compiled tool for the right OS
        // There are currently two tools:
        // FlynnPluginTool-focal: supports macos and ubuntu-focal
        // FlynnPluginTool-focal: supports macos and amazonlinux2
        //
        // When we are compiling to build the precompiled tools, only the
        // default ( FlynnPluginTool-focal ) is available.
        //
        // When we are running and want to use the pre-compiled tools, we look in
        // /etc/os-release (available on linux) to see what distro we are running
        // and to load the correct tool there.
        var tool = try? context.tool(named: "FlynnPluginTool-focal")
        
        #if os(Windows)
        if let osTool = try? context.tool(named: "FlynnPluginTool-windows") {
            tool = osTool
        }
        #endif
        
        if let osFile = try? String(contentsOfFile: "/etc/os-release") {
            if osFile.contains("Amazon Linux"),
               let osTool = try? context.tool(named: "FlynnPluginTool-amazonlinux2") {
                tool = osTool
            }
            if osFile.contains("Fedora Linux 37"),
               let osTool = try? context.tool(named: "FlynnPluginTool-fedora") {
                tool = osTool
            }
            if osFile.contains("Fedora Linux 38"),
               let osTool = try? context.tool(named: "FlynnPluginTool-fedora38") {
                tool = osTool
            }
        }
        
        guard let tool = tool else {
            fatalError("FlynnPlugin unable to load FlynnPluginTool")
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
