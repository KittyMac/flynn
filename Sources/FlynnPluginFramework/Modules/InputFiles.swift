import Foundation

class InputFiles {
    // input: path to text file where each iput file in on a line
    // output: paths to individual swift files
    
    struct Packet {
        let output: String
        let input: String
    }
    
    var filesProcessed:[String:Bool] = [:]

    func process(packet: Packet) -> [ParseFile.Packet] {
        var next: [ParseFile.Packet] = []
        
        if packet.input.hasSuffix(".swift") {
            next.append(ParseFile.Packet(output: packet.output,
                                         filePath: packet.input))
            return next
        }
                
        guard let inputsFileString = try? String(contentsOf: URL(fileURLWithPath: packet.input)) else {
            fatalError("unable to open inputs file \(packet.input)")
        }
        
        let inputFiles = inputsFileString.split(separator: "\n")
        
        for inputFile in inputFiles {
            let inputFileString = String(inputFile)
            if filesProcessed[inputFileString] == nil {
                filesProcessed[inputFileString] = true
                
                next.append(ParseFile.Packet(output: packet.output,
                                             filePath: inputFileString))
            }
        }
        
        return next
    }
    
}
