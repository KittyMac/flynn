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
                if httpRequest.method == .GET && httpRequest.url == "/hello/world" {
                    try socket.write(from: "HTTP/1.1 200 OK\nContent-Type: text/plain\nContent-Length:11\n\nHello World")
                } else {
                    try socket.write(from: "HTTP/1.1 500 Internal Server Error\nContent-Type: text/plain\nContent-Length:21\n\nInternal Server Error")
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

}
