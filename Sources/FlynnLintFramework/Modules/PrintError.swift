import Foundation
import SourceKittenFramework

typealias PrintErrorResult = ((Int) -> Void)

class PrintError {
    // input: error string
    // output: none
    
    struct Packet {
        let error: String
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
        for packet in packets {
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
