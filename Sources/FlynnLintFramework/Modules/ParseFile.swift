import Foundation
import SourceKittenFramework

class ParseFile {
    // input: path to source directory, path to swift file
    // output: SourceKitten File, SourceKitten Structure
    
    struct Packet {
        let output: String
        let filePath: String
    }
    
    func process(packets: [Packet]) -> [FileSyntax] {
        var next: [FileSyntax] = []
        
        for packet in packets {
            var filePath = packet.filePath
            var dependency = false
            if filePath.hasPrefix("+") {
                filePath = String(filePath.dropFirst())
                dependency = true
            }
            
            if let file = File(path: filePath) {
                do {
                    if file.contents.contains("Flynn") {
                        let syntax = try StructureAndSyntax(file: file)

                        var blacklist: [String] = []
                        for rule in Ruleset().all {
                            if !rule.precheck(file) {
                                blacklist.append(rule.description.identifier)
                            }
                        }

                        let fileSyntax = FileSyntax(outputPath: packet.output,
                                                    file: file,
                                                    structure: syntax.structure,
                                                    ancestry: [],
                                                    tokens: syntax.syntax,
                                                    blacklist: blacklist,
                                                    dependency: dependency)

                        next.append(fileSyntax)
                    }
                } catch {
                    print("Parsing error: \(error)")
                }
            }
        }
        
        return next
    }
    
}
