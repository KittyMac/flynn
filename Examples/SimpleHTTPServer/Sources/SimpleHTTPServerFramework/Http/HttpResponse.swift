import Flynn
import Foundation
import Socket

// swiftlint:disable line_length

public struct HttpResponse {

    static func asData(_ status: HttpStatus, _ type: HttpContentType, _ payload: Data) -> Data {
        var combined = Data(capacity: payload.count + 500)

        let header = "HTTP/1.1 \(status.rawValue) \(status.string)\nContent-Type: \(type.string)\nContent-Length:\(payload.count)\n\n"
        combined.append(Data(header.utf8))
        combined.append(payload)

        return combined
    }

    static func asData(_ status: HttpStatus, _ type: HttpContentType, _ payload: String) -> Data {
        let payloadUtf8 = payload.utf8

        var combined = Data(capacity: payloadUtf8.count + 500)
        let header = "HTTP/1.1 \(status.rawValue) \(status.string)\nContent-Type: \(type.string)\nContent-Length:\(payloadUtf8.count)\n\n\(payloadUtf8)"
        combined.append(Data(header.utf8))

        return combined
    }

    static func asData(_ status: HttpStatus, _ type: HttpContentType) -> Data {
        return asData(status, type, type.string)
    }
}
