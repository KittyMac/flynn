import XCTest
import class Foundation.Bundle

// swiftlint:disable line_length

import SimpleHTTPServerFramework

final class SimpleHTTPServerTests: XCTestCase {

    var httpRequestBuffer: UnsafeMutablePointer<CChar>?
    var httpRequestBufferSize: Int = 0

    override func setUp() {
        let requestString = """
        GET /index.html HTTP/1.1
        Host: localhost:8080
        Cache-Control: max-age=0
        Upgrade-Insecure-Requests: 1
        User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.162 Safari/537.36
        Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8
        DNT: 1
        Accept-Encoding: gzip, deflate, br
        Accept-Charset: ISO-8859-1,utf-8
        Accept-Language: en-US,en;q=0.9
        Connection: keep-alive


        """

        if let requestCString = requestString.cString(using: .utf8) {
            httpRequestBufferSize = requestCString.count
            httpRequestBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: httpRequestBufferSize)
            httpRequestBuffer?.initialize(from: requestCString, count: httpRequestBufferSize)
        }
    }

    override func tearDown() {
        httpRequestBuffer?.deallocate()
    }

    func testHttpRequestParse() throws {
        var request: HttpRequest = HttpRequest()

        measure {
            for _ in 0..<100_000 {
                request = HttpRequest(httpRequestBuffer!, httpRequestBufferSize)
            }
        }

        XCTAssert(  request.method == .GET )
        XCTAssert(  request.url == "/index.html" )
        XCTAssert(  request.host == "localhost:8080" )
        XCTAssert(  request.userAgent == "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.162 Safari/537.36" )
        XCTAssert(  request.accept == "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8" )
        XCTAssert(  request.acceptEncoding == "gzip, deflate, br" )
        XCTAssert(  request.acceptCharset == "ISO-8859-1,utf-8" )
        XCTAssert(  request.acceptLanguage == "en-US,en;q=0.9" )
        XCTAssert(  request.connection == "keep-alive" )
    }

    func testConstant() throws {

        measure {
            var sum: CChar = 0
            for _ in 0..<100000000 {
                // equivalent of 'a' in C
                sum = 97
            }
            XCTAssert(sum == 97)
        }
    }

    func testCChar() throws {

        measure {
            var sum: CChar = 0
            for _ in 0..<100000000 {
                sum = CChar.a
            }
            XCTAssert(sum == 97)
        }
    }

    func testCharacter() throws {
        measure {
            var sum: UInt8 = 0
            for _ in 0..<100000000 {
                sum = Character("a").asciiValue!
            }
            XCTAssert(sum == 97)
        }
    }

    static var allTests = [
        ("testCChar", testCChar),
        ("testCharacter", testCharacter)
    ]
}
