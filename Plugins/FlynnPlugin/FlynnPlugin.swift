import Foundation
import PackagePlugin

@main struct FlynnPlugin: BuildToolPlugin {
    
    func gatherSwiftInputFiles(targets: [Target],
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
            
            let url = URL(fileURLWithPath: target.directory.string)
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
        
        let tool = try context.tool(named: "FlynnLint")
        
        // Find all .swift files in our target and all of our target's dependencies, add them as input files
        var rootFiles: [PackagePlugin.Path] = []
        var dependencyFiles: [PackagePlugin.Path] = []
        
        gatherSwiftInputFiles(targets: [target],
                              inputFiles: &rootFiles)
        gatherSwiftInputFiles(targets: target.recursiveTargetDependencies,
                              inputFiles: &dependencyFiles)
        
        let allInputFiles = rootFiles + dependencyFiles
                
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
        let outputFilePath = context.pluginWorkDirectory.string + "/FlynnLint.swift"
        
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
