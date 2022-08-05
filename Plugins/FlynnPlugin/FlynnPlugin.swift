import Foundation
import PackagePlugin

@main struct FlynnPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        
        guard let target = target as? SwiftSourceModuleTarget else {
            return []
        }

        let tool = try context.tool(named: "FlynnLint")
        
        print(tool.path)
        print(target.directory.string)
        print(context.pluginWorkDirectory)
        
        //fatalError("HI")

        return [
            .prebuildCommand(
                displayName: "FlynnLint generating behaviours",
                executable: tool.path,
                arguments: [
                    "-o",
                    context.pluginWorkDirectory,
                    target.directory.string
                ],
                outputFilesDirectory: context.pluginWorkDirectory
            )
        ]
    }
}
