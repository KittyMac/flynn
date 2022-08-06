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
            if let file = File(path: packet.filePath) {
                do {
                    let syntax = try StructureAndSyntax(file: file)

                    var blacklist: [String] = []
                    for rule in Ruleset().all {
                        if !rule.precheck(file) {
                            blacklist.append(rule.description.identifier)
                        }
                    }

                    let fileSyntax = FileSyntax(packet.output,
                                                file,
                                                syntax.structure,
                                                [],
                                                syntax.syntax,
                                                blacklist)

                    next.append(fileSyntax)
                } catch {
                    print("Parsing error: \(error)")
                }
            }
        }
        
        return next
    }
    
}
