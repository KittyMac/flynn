import Flynn
import Foundation
import Socket

public class Connection: Actor {

    private let socket: Socket

    private let bufferSize = 16384
    private var buffer: UnsafeMutablePointer<CChar>

    public init(socket: Socket) {
        self.socket = socket

        try? socket.setReadTimeout(value: 25)

        buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
        buffer.initialize(to: 0)

        super.init()

        beNextCommand()
    }

    deinit {
        buffer.deallocate()
    }

    private func _beNextCommand() {
        if socket.remoteConnectionClosed {
            return
        }

        do {
            if try socket.read(into: buffer, bufSize: bufferSize, truncate: true) > 0 {
                let httpRequest = HttpRequest(buffer, bufferSize)
                if httpRequest.method == .GET {
                    if let url = httpRequest.url {
                        if url == "/hello/world" {
                            try socket.write(from: HttpResponse.asData(.ok, .txt, "Hello World"))
                        } else {
                            var fixedUrl = url
                            if url.hasSuffix("/") {
                                fixedUrl = url + "/index.html"
                            }
                            Files.shared.beGetFile(fixedUrl, self, beBeSendFileResponse)
                            return
                        }
                    }
                }
            } else {
                unsafeYield()
            }
            beNextCommand()
        } catch {
            self.socket.close()
        }
    }

    lazy var beNextCommand = Behavior(self) { [unowned self] (_: BehaviorArgs) in
        self._beNextCommand()
    }

    lazy var beBeSendFileResponse = Behavior(self) { [unowned self] (args: BehaviorArgs) in
        // flynnlint:parameter Data - data of the file
        // flynnlint:parameter HttpContentType - content type of the file
        let data: Data = args[x:0]
        let type: HttpContentType = args[x:1]
        do {
            if data.count == 0 {
                try self.socket.write(from: HttpResponse.asData(.internalServerError, .txt))
            } else {
                try self.socket.write(from: HttpResponse.asData(.ok, type, data))
            }
            self.beNextCommand()
        } catch {
            self.socket.close()
        }
    }

}
