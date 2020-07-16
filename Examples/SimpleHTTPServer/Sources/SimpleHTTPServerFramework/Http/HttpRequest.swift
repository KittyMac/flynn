import Flynn
import Foundation
import Socket

// swiftlint:disable function_body_length
// swiftlint:disable cyclomatic_complexity

public struct HttpRequest {
    public var method: HttpMethod?
    
    @InMemory public var url: String?
    @InMemory public var host: String?
    @InMemory public var userAgent: String?
    @InMemory public var accept: String?
    @InMemory public var acceptEncoding: String?
    @InMemory public var acceptCharset: String?
    @InMemory public var acceptLanguage: String?
    @InMemory public var connection: String?
    
    public init() {

    }

    public init(_ buffer: UnsafeMutablePointer<CChar>, _ bufferSize: Int) {

        let startPtr = buffer
        let endPtr = buffer + bufferSize

        var ptr = startPtr + 3

        var lineNumber = 0

        while ptr < endPtr {
            if lineNumber == 0 {
                if method == nil {
                    if  (ptr-3).pointee == CChar.G &&
                        (ptr-2).pointee == CChar.E &&
                        (ptr-1).pointee == CChar.T &&
                        ptr.pointee == CChar.space {
                        method = .GET
                    } else if
                        (ptr-4).pointee == CChar.H &&
                        (ptr-3).pointee == CChar.E &&
                        (ptr-2).pointee == CChar.A &&
                        (ptr-1).pointee == CChar.D &&
                        ptr.pointee == CChar.space {
                        method = .HEAD
                    } else if
                        (ptr-3).pointee == CChar.P &&
                        (ptr-2).pointee == CChar.U &&
                        (ptr-1).pointee == CChar.T &&
                        ptr.pointee == CChar.space {
                        method = .PUT
                    } else if
                        (ptr-4).pointee == CChar.P &&
                        (ptr-3).pointee == CChar.O &&
                        (ptr-2).pointee == CChar.S &&
                        (ptr-1).pointee == CChar.T &&
                        ptr.pointee == CChar.space {
                        method = .POST
                    } else if
                        (ptr-6).pointee == CChar.D &&
                        (ptr-5).pointee == CChar.E &&
                        (ptr-4).pointee == CChar.L &&
                        (ptr-3).pointee == CChar.E &&
                        (ptr-2).pointee == CChar.T &&
                        (ptr-1).pointee == CChar.E &&
                        ptr.pointee == CChar.space {
                        method = .DELETE
                    }

                    // We identified the method, now parse the rest of the line
                    if method != nil {
                        let urlStartPtr = ptr + 1
                        var urlEndPtr = ptr + 1
                        while ptr < endPtr {
                            if ptr.pointee == CChar.newLine {
                                break
                            }
                            if ptr.pointee == CChar.space {
                                urlEndPtr = ptr
                            }
                            ptr += 1
                        }
                        $url = InMemory(initialValue: nil, urlStartPtr, urlEndPtr)
                    }
                }
            } else {
                // Every line after the header is a Key-Word-No-Space: Whatever Until New Line
                // 1. advance until we find the ":", or a whitespace
                var keyEnd = ptr + 1
                while ptr < endPtr {
                    if ptr.pointee == CChar.newLine || ptr.pointee == CChar.space {
                        return
                    }
                    if ptr.pointee == CChar.colon {
                        keyEnd = ptr
                        ptr += 1
                        break
                    }
                    ptr += 1
                }

                // 2. Skip whitespace
                while ptr < endPtr && (ptr.pointee == CChar.space || ptr.pointee == CChar.tab) {
                    ptr += 1
                }

                let valueStart = ptr

                // 3. Advance to the end of the line
                while ptr < endPtr && ptr.pointee != CChar.newLine {
                    ptr += 1
                }

                // 3. For speed, we only match against the keys we support (no generics)
                if  $host.isEmpty() &&
                    (keyEnd-4).pointee == CChar.H &&
                    (keyEnd-3).pointee == CChar.o &&
                    (keyEnd-2).pointee == CChar.s &&
                    (keyEnd-1).pointee == CChar.t {
                    $host = InMemory(initialValue: nil, valueStart, ptr)
                }

                if  $userAgent.isEmpty() &&
                    (keyEnd-10).pointee == CChar.U &&
                    (keyEnd-9).pointee == CChar.s &&
                    (keyEnd-8).pointee == CChar.e &&
                    (keyEnd-7).pointee == CChar.r &&
                    (keyEnd-6).pointee == CChar.minus &&
                    (keyEnd-5).pointee == CChar.A &&
                    (keyEnd-4).pointee == CChar.g &&
                    (keyEnd-3).pointee == CChar.e &&
                    (keyEnd-2).pointee == CChar.n &&
                    (keyEnd-1).pointee == CChar.t {
                    $userAgent = InMemory(initialValue: nil, valueStart, ptr)
                }
                
                if  $accept.isEmpty() &&
                    (keyEnd-6).pointee == CChar.A &&
                    (keyEnd-5).pointee == CChar.c &&
                    (keyEnd-4).pointee == CChar.c &&
                    (keyEnd-3).pointee == CChar.e &&
                    (keyEnd-2).pointee == CChar.p &&
                    (keyEnd-1).pointee == CChar.t {
                    $accept = InMemory(initialValue: nil, valueStart, ptr)
                }
                
                if  $acceptEncoding.isEmpty() &&
                    (keyEnd-15).pointee == CChar.A &&
                    (keyEnd-14).pointee == CChar.c &&
                    (keyEnd-13).pointee == CChar.c &&
                    (keyEnd-12).pointee == CChar.e &&
                    (keyEnd-11).pointee == CChar.p &&
                    (keyEnd-10).pointee == CChar.t &&
                    (keyEnd-9).pointee == CChar.minus &&
                    (keyEnd-8).pointee == CChar.E &&
                    (keyEnd-7).pointee == CChar.n &&
                    (keyEnd-6).pointee == CChar.c &&
                    (keyEnd-5).pointee == CChar.o &&
                    (keyEnd-4).pointee == CChar.d &&
                    (keyEnd-3).pointee == CChar.i &&
                    (keyEnd-2).pointee == CChar.n &&
                    (keyEnd-1).pointee == CChar.g {
                    $acceptEncoding = InMemory(initialValue: nil, valueStart, ptr)
                }
                
                if  $acceptCharset.isEmpty() &&
                    (keyEnd-14).pointee == CChar.A &&
                    (keyEnd-13).pointee == CChar.c &&
                    (keyEnd-12).pointee == CChar.c &&
                    (keyEnd-11).pointee == CChar.e &&
                    (keyEnd-10).pointee == CChar.p &&
                    (keyEnd-9).pointee == CChar.t &&
                    (keyEnd-8).pointee == CChar.minus &&
                    (keyEnd-7).pointee == CChar.C &&
                    (keyEnd-6).pointee == CChar.h &&
                    (keyEnd-5).pointee == CChar.a &&
                    (keyEnd-4).pointee == CChar.r &&
                    (keyEnd-3).pointee == CChar.s &&
                    (keyEnd-2).pointee == CChar.e &&
                    (keyEnd-1).pointee == CChar.t {
                    $acceptCharset = InMemory(initialValue: nil, valueStart, ptr)
                }
                
                if  $acceptLanguage.isEmpty() &&
                    (keyEnd-15).pointee == CChar.A &&
                    (keyEnd-14).pointee == CChar.c &&
                    (keyEnd-13).pointee == CChar.c &&
                    (keyEnd-12).pointee == CChar.e &&
                    (keyEnd-11).pointee == CChar.p &&
                    (keyEnd-10).pointee == CChar.t &&
                    (keyEnd-9).pointee == CChar.minus &&
                    (keyEnd-8).pointee == CChar.L &&
                    (keyEnd-7).pointee == CChar.a &&
                    (keyEnd-6).pointee == CChar.n &&
                    (keyEnd-5).pointee == CChar.g &&
                    (keyEnd-4).pointee == CChar.u &&
                    (keyEnd-3).pointee == CChar.a &&
                    (keyEnd-2).pointee == CChar.g &&
                    (keyEnd-1).pointee == CChar.e {
                    $acceptLanguage = InMemory(initialValue: nil, valueStart, ptr)
                }
                
                if  $connection.isEmpty() &&
                    (keyEnd-10).pointee == CChar.C &&
                    (keyEnd-9).pointee == CChar.o &&
                    (keyEnd-8).pointee == CChar.n &&
                    (keyEnd-7).pointee == CChar.n &&
                    (keyEnd-6).pointee == CChar.e &&
                    (keyEnd-5).pointee == CChar.c &&
                    (keyEnd-4).pointee == CChar.t &&
                    (keyEnd-3).pointee == CChar.i &&
                    (keyEnd-2).pointee == CChar.o &&
                    (keyEnd-1).pointee == CChar.n {
                    $connection = InMemory(initialValue: nil, valueStart, ptr)
                }

            }

            if ptr.pointee == CChar.newLine {
                lineNumber += 1
                if method == nil {
                    // we should have parsed the HTTP method on the first line, so
                    // exit early since that failed
                    break
                }
            }

            ptr += 1
        }

    }

}
