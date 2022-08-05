import Foundation
import PackagePlugin

@main struct FlynnPlugin: BuildToolPlugin {
    
    func gatherSwiftInputFiles(target: Target,
                               inputFiles: inout [PackagePlugin.Path]) {
        
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
        
        for dependency in target.dependencies {
            switch dependency {
            case .target(let target):
                gatherSwiftInputFiles(target: target,
                                      inputFiles: &inputFiles)
                break
            default:
                break
            }
        }
    }
    
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        
        guard let target = target as? SwiftSourceModuleTarget else {
            return []
        }

        let tool = try context.tool(named: "FlynnLint")
        
        print(tool.path)
        print(target.directory.string)
        print(context.pluginWorkDirectory)
        
        // Find all .swift files in our target and all of our target's dependencies, add them as input files
        var inputFiles: [PackagePlugin.Path] = []
        gatherSwiftInputFiles(target: target,
                              inputFiles: &inputFiles)
        
        print(inputFiles)
        
        let inputFilesFilePath = context.pluginWorkDirectory.string + "/inputFiles.txt"
        try! inputFiles.map { $0.string }.joined(separator: "\n").write(toFile: inputFilesFilePath, atomically: false, encoding: .utf8)
        
        let outputFilePath = context.pluginWorkDirectory.string + "/FlynnLint.swift"
        
        return [
            .buildCommand(
                displayName: "Flynn Plugin - checking concurrency safety, generating behaviours...",
                executable: tool.path,
                arguments: [
                    inputFilesFilePath,
                    outputFilePath
                ],
                inputFiles: inputFiles,
                outputFiles: [
                    PackagePlugin.Path(outputFilePath)
                ]
            )
        ]
    }
}
