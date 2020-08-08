import Foundation
import Flynn
import Socket
import SimpleHTTPServerFramework

let address = "0.0.0.0"
let port = 8080

do {
    let serverSocket = try Socket.create()
    try serverSocket.listen(on: port, node: address)

    Files.shared.beSetRoot("/tmp/www/")

    repeat {
        autoreleasepool {
            if let newSocket = try? serverSocket.acceptClientConnection() {
                _ = Connection(socket: newSocket)
            }
        }
    } while true

} catch {
    print("socket error: \(error)")
    exit(1)
}
