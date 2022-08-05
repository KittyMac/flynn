//
//  main.swift
//  flynnlint
//
//  Created by Rocco Bowling on 5/29/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import FlynnLintFramework
import Flynn

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
        
        try? FileManager.default.removeItem(atPath: output)
        try! "".write(toFile: output, atomically: false, encoding: .utf8)
        
        flynnlint.process(input: input,
                          output: output)
        
        let exitCode = flynnlint.finish()
        if exitCode != 0 {
            throw ExitCode(Int32(exitCode))
        }
    }
}

FlynnLintCLI.main()
