import Foundation
import SourceKittenFramework

typealias PrintErrorResult = ((Int) -> Void)

class PrintError {
    // input: error string
    // output: none
    
    struct Packet {
        let error: String
        let dependecy: Bool
        let warning: Bool
    }

    private var onComplete: PrintErrorResult?
    private var numErrors: Int = 0

    init(_ onComplete: @escaping PrintErrorResult) {
        self.onComplete = onComplete
    }
    
    init() {
        onComplete = nil
    }

    func process(packets: [Packet]) {
        var dedup = Set<String>()
        
        for packet in packets {
            guard dedup.contains(packet.error) == false else { continue }
            
            // suppress printing warnings generated in dependencies
            if packet.dependecy && packet.warning {
                continue
            }
            
            dedup.insert(packet.error)
            print(packet.error)
            if packet.error.contains("error") {
                self.numErrors += 1
            }
        }

        if let onComplete = self.onComplete {
            onComplete(self.numErrors)
        }
    }
}
