import Foundation
import SourceKittenFramework

// Note: FlynnLint used to use Flynn, but in order to implement FlynnLint
// as a Swift Package Manager Build Tool FlynnLint cannot have Flynn as
// as a dependency (it introduces a circular dependency). Much of this
// code was modified quickly to strip Flynn from it, so its architecture
// is a little weird looking without it.

public class FlynnLint {

    static let prefixBehaviorExternal = "be"
    static let prefixBehaviorInternal = "_be"
    static let prefixSafe = "safe"
    static let prefixUnsafe = "unsafe"

    private var numErrors: Int = 0
    
    private var buildCombinedAST = BuildCombinedAST()

    public init() {
        SourceKittenConfiguration.preferInProcessSourceKit = true
    }

    @discardableResult
    public func process(input: String,
                        output: String) -> Int {
        let ruleset = Ruleset()
        
        try? FileManager.default.removeItem(atPath: output)
        try? "import Foundation\nimport Flynn\n".write(toFile: output, atomically: false, encoding: .utf8)
        
        print("\(output): warning: FlynnLint generated code")
        
        let inputFiles = InputFiles()
        let parseFile = ParseFile()
        let buildCombinedAST = BuildCombinedAST()
        let autogenerateBehaviours = AutogenerateExternalBehaviors()
        let checkRules = CheckRules(ruleset)
        let printError = PrintError { (numErrors: Int) in
            self.numErrors += numErrors
        }
        
        let step1 = inputFiles.process(packet: InputFiles.Packet(output: output, input: input))
        let step2 = parseFile.process(packets: step1)
        let step3 = buildCombinedAST.process(fileSyntaxes: step2)
        let step4 = autogenerateBehaviours.process(packets: step3)
        let step5 = checkRules.process(packets: step4)
        let _ = printError.process(packets: step5)
        
        return numErrors
    }
    
    @discardableResult
    public func process(inputs: [String],
                        output: String) -> Int {
        let ruleset = Ruleset()
        
        try? FileManager.default.removeItem(atPath: output)
        try? "import Foundation\nimport Flynn\n".write(toFile: output, atomically: false, encoding: .utf8)
        
        print("\(output): warning: FlynnLint generated code")
        
        let parseFile = ParseFile()
        let buildCombinedAST = BuildCombinedAST()
        let autogenerateBehaviours = AutogenerateExternalBehaviors()
        let checkRules = CheckRules(ruleset)
        let printError = PrintError { (numErrors: Int) in
            self.numErrors += numErrors
        }
        
        let step1 = inputs.map { ParseFile.Packet(output: output, filePath: $0) }
        let step2 = parseFile.process(packets: step1)
        let step3 = buildCombinedAST.process(fileSyntaxes: step2)
        let step4 = autogenerateBehaviours.process(packets: step3)
        let step5 = checkRules.process(packets: step4)
        let _ = printError.process(packets: step5)
        
        return numErrors
    }
}
