import Foundation
import FlynnPluginFramework

import ArgumentParser


struct FlynnPluginToolCLI: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "flynnplugin",
        abstract: "FlynnPlugin is a SPM build tool which supports Flynn (https://github.com/KittyMac/Flynn)",
        subcommands: [Generate.self, Skip.self],
        defaultSubcommand: Generate.self)
        
    struct Generate: ParsableCommand {
        @Argument(help: "Path to single Swift file or text file containing swift files")
        var input: String
        
        @Argument(help: "Path to output file")
        var output: String

        mutating func run() throws {
            if let buildAction = ProcessInfo.processInfo.environment["ACTION"],
               buildAction == "indexbuild" {
                return
            }
            
            let flynnplugintool = FlynnPluginTool()
                    
            let exitCode = flynnplugintool.process(input: input,
                                                 output: output)
            
            if exitCode != 0 {
                throw ExitCode(Int32(exitCode))
            }
        }
    }
    
    struct Skip: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Don't do anything")
                
        mutating func run() {
            
        }
    }
}

FlynnPluginToolCLI.main()
