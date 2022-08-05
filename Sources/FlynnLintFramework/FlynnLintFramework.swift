//
//  main.swift
//  flynnlint
//
//  Created by Rocco Bowling on 5/29/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

import Foundation
import Flynn
import SourceKittenFramework

public class FlynnLint {

    static let prefixBehaviorExternal = "be"
    static let prefixBehaviorInternal = "_be"
    static let prefixSafe = "safe"
    static let prefixUnsafe = "unsafe"

    private var pipeline: Flowable?
    private var numErrors: Int = 0
    
    private var buildCombinedAST = BuildCombinedAST()

    public init() {
        Flynn.startup()
        
        SourceKittenConfiguration.preferInProcessSourceKit = true
        
        let ruleset = Ruleset()
        let poolSize = max(1, Flynn.cores - 2)
        
        pipeline = InputFiles() |>
            Array(count: poolSize) { ParseFile() } |>
            buildCombinedAST |>
            Array(count: poolSize) { AutogenerateExternalBehaviors() } |>
            Array(count: poolSize) { CheckRules(ruleset) } |>
            PrintError { (numErrors: Int) in
                self.numErrors += numErrors
            }
    }

    public func process(input: String,
                        output: String) {
        pipeline!.beFlow([output, input])
        pipeline!.beFlow([])
    }

    @discardableResult
    public func finish() -> Int {
        pipeline?.unsafeWait(0)
        buildCombinedAST.unsafeWait(0)
        Flynn.shutdown()
        return numErrors
    }
}
