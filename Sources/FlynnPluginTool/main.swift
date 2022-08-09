import Foundation
import FlynnPluginFramework

import ArgumentParser


struct FlynnPluginToolCLI: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "flynnplugin",
        abstract: "FlynnPlugin is a SPM build tool which supports Flynn (https://github.com/KittyMac/Flynn)"
    )
        
    @Argument(help: "Path to single Swift file or text file containing swift files")
    var input: String
    
    @Argument(help: "Path to output file")
    var output: String

    mutating func run() throws {
        let flynnplugintool = FlynnPluginTool()
                
        let exitCode = flynnplugintool.process(input: input,
                                             output: output)
        
        if exitCode != 0 {
            throw ExitCode(Int32(exitCode))
        }
    }
}

FlynnPluginToolCLI.main()
