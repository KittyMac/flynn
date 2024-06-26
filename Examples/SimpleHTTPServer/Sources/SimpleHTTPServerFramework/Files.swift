import Flynn
import Foundation
import Socket

public protocol FilesReceiver {
    @discardableResult
    func beFileData(_ data: Data, _ type: HttpContentType) -> Self
}

public class Files: Actor {
    // In this example, we are going to treat the file system as a critical resource whose access
    // is optimized my limited the number of concurrent accesses to said resource. The Files
    // actor are the only actors allowed to access the file system, and all Connection actors
    // need to communicate with them in order to serve files over HTTP
    public static let shared = Files()
    private override init() {}

    private var root: String = ""

    internal func _beSetRoot(_ root: String) {
        self.root = root
    }

    internal func _beGetFile(_ path: String, _ sender: FilesReceiver) {
        let fullPath = root + path
        if let data = try? Data(contentsOf: URL(fileURLWithPath: fullPath)) {
            sender.beFileData(data, HttpContentType.fromPath(path))
        } else {
            sender.beFileData(Data(), HttpContentType.txt)
        }
    }
}
