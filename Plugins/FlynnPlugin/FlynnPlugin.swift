import Foundation
import PackagePlugin

@main struct FlynnPlugin: BuildToolPlugin {
    
    func gatherSwiftInputFiles(target: Target,
                               isRoot: Bool,
                               inputFiles: inout [PackagePlugin.Path]) {
        
        let url = URL(fileURLWithPath: target.directory.string)
        if let enumerator = FileManager.default.enumerator(at: url,
                                                           includingPropertiesForKeys: [.isRegularFileKey],
                                                           options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let fileURL as URL in enumerator {
                do {
                    let fileAttributes = try fileURL.resourceValues(forKeys:[.isRegularFileKey])
                    if fileAttributes.isRegularFile == true && fileURL.pathExtension == "swift" {
                        if isRoot {
                            inputFiles.append(PackagePlugin.Path(fileURL.path))
                        } else {
                            inputFiles.append(PackagePlugin.Path("+" + fileURL.path))
                        }
                    }
                } catch { print(error, fileURL) }
            }
        }
        
        for dependency in target.dependencies {
            switch dependency {
            case .target(let target):
                gatherSwiftInputFiles(target: target,
                                      isRoot: false,
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
                
        // Find all .swift files in our target and all of our target's dependencies, add them as input files
        var inputFiles: [PackagePlugin.Path] = []
        gatherSwiftInputFiles(target: target,
                              isRoot: true,
                              inputFiles: &inputFiles)
                
        let inputFilesFilePath = context.pluginWorkDirectory.string + "/inputFiles.txt"
        try! inputFiles.map { $0.string }.joined(separator: "\n").write(toFile: inputFilesFilePath, atomically: false, encoding: .utf8)
        
        let outputFilePath = context.pluginWorkDirectory.string + "/FlynnLint.swift"
        
        return [
            .buildCommand(
                displayName: "Flynn Plugin - generating behaviours...",
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
