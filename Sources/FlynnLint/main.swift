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
    
    @Option(name: NameSpecification.shortAndLong,
            help: "Directory to generate source files")
    var output: String?
    
    @Argument(help: "Source directories for FlynnLint to check")
    var source: [String] = []

    mutating func run() throws {
        guard let output = output else {
            fatalError("output directory missing")
        }
        let flynnlint = FlynnLint()
        for path in source {
            flynnlint.process(output: output,
                              source: path)
        }
        
        //exit(Int32(flynnlint.finish()))
    }
}

FlynnLintCLI.main()
