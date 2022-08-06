import Foundation
import FlynnLintFramework

import ArgumentParser


struct FlynnLintCLI: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "flynnlint",
        abstract: "FlynnLint is a SPM build tool which supports Flynn (https://github.com/KittyMac/Flynn)"
    )
        
    @Argument(help: "Path to single Swift file or text file containing swift files")
    var input: String
    
    @Argument(help: "Path to output file")
    var output: String

    mutating func run() throws {
        let flynnlint = FlynnLint()
                
        let exitCode = flynnlint.process(input: input,
                                         output: output)
        
        if exitCode != 0 {
            throw ExitCode(Int32(exitCode))
        }
    }
}

FlynnLintCLI.main()
