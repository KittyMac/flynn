import Flynn
import Foundation
import Socket

public class Connection: Actor, FilesReceiver {
    private let socket: Socket

    private let bufferSize = 16384
    private var buffer: UnsafeMutablePointer<CChar>

    public init(socket: Socket) {
        self.socket = socket

        try? socket.setReadTimeout(value: 5)

        buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
        buffer.initialize(to: 0)

        super.init()

        // This actor will process up to this many behaviors before it must allow
        // allow another actor scheduler access.
        unsafeMessageBatchSize = 1

        beNextCommand()
    }

    deinit {
        buffer.deallocate()
    }

    internal func _beNextCommand() {
        // Checks the socket to see if there is an HTTP command ready to be processed.
        // Whether we process one or not, we call beNextCommand() to check again in
        // the future for another command.
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
                            Files.shared.beGetFile(fixedUrl, self)
                            return
                        }
                    }
                }
            }

            beNextCommand()
        } catch {
            socket.close()
        }
    }

    internal func _beFileData(_ data: Data, _ type: HttpContentType) {
        do {
            if data.count == 0 {
                try socket.write(from: HttpResponse.asData(.internalServerError, .txt))
            } else {
                try socket.write(from: HttpResponse.asData(.ok, type, data))
            }

            beNextCommand()
        } catch {
            socket.close()
        }
    }

}
