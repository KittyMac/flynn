import Foundation
import SourceKittenFramework

// Note: FlynnPluginFramework used to use Flynn, but in order to implement FlynnPluginFramework
// as a Swift Package Manager Build Tool FlynnPluginFramework cannot have Flynn as
// as a dependency (it introduces a circular dependency). Much of this
// code was modified quickly to strip Flynn from it, so its architecture
// is a little weird looking without it.

/*
var logs: [String] = []

internal func print(_ items: String..., filename: String = #file, function : String = #function, line: Int = #line, separator: String = " ", terminator: String = "\n") {
    let pretty = "\(URL(fileURLWithPath: filename).lastPathComponent) [#\(line)] \(function)\n\t-> "
    let output = items.map { "\($0)" }.joined(separator: separator)
    Swift.print(pretty+output, terminator: terminator)
    logs.append(output)
}

internal func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let output = items.map { "\($0)" }.joined(separator: separator)
    Swift.print(output, terminator: terminator)
    logs.append(output)
}

internal func clearLogs() {
    try? FileManager.default.removeItem(atPath: "/tmp/FlynnPluginFramework.log")
}

internal func exportLogs() {
    let logString = logs.joined(separator: "\n")
    try? logString.write(toFile: "/tmp/FlynnPluginFramework.log", atomically: false, encoding: .utf8)
}
 */

extension Array {
    func chunked(divisions: Int) -> [[Element]] {
        let chunkSize = Int((Double(count) / Double(divisions)).rounded(.up))
        let fchunkSize = Swift.max(chunkSize, 1)
        return stride(from: 0, to: self.count, by: fchunkSize).map {
            Array(self[$0..<Swift.min($0 + fchunkSize, self.count)])
        }
    }
}

public class FlynnPluginTool {

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
                
        guard let inputsFileString = try? String(contentsOf: URL(fileURLWithPath: input)) else {
            fatalError("unable to open inputs file \(input)")
        }
        
        let inputFiles = inputsFileString.split(separator: "\n")
        
        return process(inputs: inputFiles.map { String($0) },
                       output: output)
    }
    
    @discardableResult
    public func process(inputs: [String],
                        output: String) -> Int {
        
        //clearLogs(); defer { exportLogs() }
        
        let ruleset = Ruleset()
        
        try? FileManager.default.removeItem(atPath: output)
        try? "import Foundation\n".write(toFile: output, atomically: false, encoding: .utf8)
        
        //print("\(output): warning: FlynnPluginTool generated code")
        
        let cores = ProcessInfo.processInfo.activeProcessorCount
        
        var parseFile: [ParseFile] = []
        let buildCombinedAST = BuildCombinedAST()
        var autogenerateBehaviours: [AutogenerateExternalBehaviors] = []
        var checkRules: [CheckRules] = []
        let printError = PrintError { (numErrors: Int) in
            self.numErrors += numErrors
        }
        
        for _ in 0..<cores+1 {
            parseFile.append(ParseFile())
            autogenerateBehaviours.append(AutogenerateExternalBehaviors())
            checkRules.append(CheckRules(ruleset))
        }
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = ProcessInfo.processInfo.activeProcessorCount
        
        print(inputs)

        let step1 = inputs.map { ParseFile.Packet(output: output, filePath: $0) }
        
        var step2: [FileSyntax] = []
        if true {
            let inputs = step1.chunked(divisions: cores)
            let lock = NSLock()
            for idx in 0..<inputs.count {
                queue.addOperation {
                    let result = parseFile[idx].process(packets: inputs[idx])
                    lock.lock()
                    step2.append(contentsOf: result)
                    lock.unlock()
                }
            }
            queue.waitUntilAllOperationsAreFinished()
        }
        
        let step3 = buildCombinedAST.process(fileSyntaxes: step2)
        
        // parallelize
        var step4: [AutogenerateExternalBehaviors.Packet] = []
        if true {
            let inputs = step3.chunked(divisions: cores)
            let lock = NSLock()
            for idx in 0..<inputs.count {
                queue.addOperation {
                    let result = autogenerateBehaviours[idx].process(packets: inputs[idx])
                    lock.lock()
                    step4.append(contentsOf: result)
                    lock.unlock()
                }
            }
            queue.waitUntilAllOperationsAreFinished()
        }
        
        // parallelize
        var step5: [PrintError.Packet] = []
        if true {
            let inputs = step4.chunked(divisions: cores)
            let lock = NSLock()
            for idx in 0..<inputs.count {
                queue.addOperation {
                    let result = checkRules[idx].process(packets: inputs[idx])
                    lock.lock()
                    step5.append(contentsOf: result)
                    lock.unlock()
                }
            }
            queue.waitUntilAllOperationsAreFinished()
        }
        
        let _ = printError.process(packets: step5)
        
        return numErrors
    }
    
}
