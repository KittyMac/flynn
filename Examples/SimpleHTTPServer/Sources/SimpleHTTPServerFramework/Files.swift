import Flynn
import Foundation
import Socket

public class Files: Actor {
    // In this example, we are going to treat the file system as a critical resource whose access
    // is optimized my limited the number of concurrent accesses to said resource. The Files
    // actor are the only actors allowed to access the file system, and all Connection actors
    // need to communicate with them in order to serve files over HTTP
    public static let shared = Files()
    private override init() {}

    private var root: String = ""

    public lazy var beSetRoot = Behavior(self) { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter String - path to root web directory
        self.root = args[x:0]
    }

    public lazy var beGetFile = Behavior(self) { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter String - local path to file contents
        // flynnlint:parameter Actor - calling actor
        // flynnlint:parameter Behavior - the callback behavior
        let path: String = args[x:0]
        let sender: Actor = args[x:1]
        let callback: Behavior = args[x:2]
        let fullPath = self.root + path

        if let data = try? Data(contentsOf: URL(fileURLWithPath: fullPath)) {
            callback(data, HttpContentType.fromPath(path))
        } else {
            callback(Data(), HttpContentType.txt)
        }

    }
}
