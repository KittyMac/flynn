import Foundation
import PackagePlugin

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

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension FlynnPlugin: XcodeBuildToolPlugin {
    
    fileprivate func gatherSwiftInputFiles(targets: [XcodeTarget],
                                           inputFiles: inout [PackagePlugin.Path]) {
        
        for target in targets {
            
            var hasFlynnDependency = target.displayName == "Flynn"
            for dependency in target.dependencies {
                switch dependency {
                case .target(let target):
                    if target.displayName == "Flynn" {
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
            
            guard hasFlynnDependency || targets.count == 1 else { continue }
            
            for targetFile in target.inputFiles {
                if targetFile.type == .source && targetFile.path.extension == "swift" {
                    inputFiles.append(targetFile.path)
                }
            }
        }
    }

    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
                
        // Note: We want to load the right pre-compiled tool for the right OS
        // There are currently two tools:
        // FlynnPluginTool-focal: supports macos and ubuntu-focal
        // FlynnPluginTool-focal: supports macos and amazonlinux2
        let tool = try? context.tool(named: "FlynnPluginTool-focal")
        
        guard let tool = tool else {
            fatalError("FlynnPlugin unable to load FlynnPluginTool")
        }
        
        // Find all .swift files in our target and all of our target's dependencies, add them as input files
        var rootFiles: [PackagePlugin.Path] = []
        var dependencyFiles: [PackagePlugin.Path] = []
        
        
        gatherSwiftInputFiles(targets: [target],
                              inputFiles: &rootFiles)
        
        var recursiveTargets: [XcodeTarget] = []
        let recurseTargets: () -> () = {
            for dependency in target.dependencies {
                switch dependency {
                case .target(let x):
                    if recursiveTargets.contains(where: { $0.id == x.id }) == false {
                        recursiveTargets.append(x)
                    }
                    break
                default:
                    break
                }
            }
        }
        recurseTargets()
                
        gatherSwiftInputFiles(targets: recursiveTargets,
                              inputFiles: &dependencyFiles)
        
        // let allInputFiles = rootFiles + dependencyFiles
                        
        let inputFilesFilePath = context.pluginWorkDirectory.string + "/inputFiles.txt"
        var inputFilesString = ""
                
        for file in rootFiles {
            inputFilesString.append("\(file)\n")
        }
        for file in dependencyFiles {
            inputFilesString.append("+\(file)\n")
        }

        try! inputFilesString.write(toFile: inputFilesFilePath, atomically: false, encoding: .utf8)
        
        // let outputFilePath = context.pluginWorkDirectory.string + "/" + UUID().uuidString + ".swift"
        let outputFilePath = context.pluginWorkDirectory.string + "/FlynnPlugin.swift"
        
        // Note: it seems that XcodeBuildToolPlugin (unlike BuildToolPlugin) won't compile the original
        // source code if it is provided in inputFiles; it must make the assumption that you are
        // replace that source code instead of just augmenting it. sigh.
        return [
            .buildCommand(
                displayName: "Flynn Plugin - generating behaviours...",
                executable: tool.path,
                arguments: [
                    inputFilesFilePath,
                    outputFilePath
                ],
                inputFiles: [],
                outputFiles: [
                    PackagePlugin.Path(outputFilePath)
                ]
            )
        ]
    }
}
#endif

