import Flynn
import Foundation
import Socket

// swiftlint:disable identifier_name

public enum HttpMethod {
    case GET
    case HEAD
    case PUT
    case POST
    case DELETE
}

public enum HttpStatus: Int {
    case ok = 200
    case badRequest = 400
    case notFound = 404
    case requestTimeout = 408
    case requestTooLarge = 413
    case internalServerError = 500

    var string: String {
        switch self {
        case .ok: return "HTTP/1.1 200 OK"
        case .badRequest: return "HTTP/1.1 400 Bad Request"
        case .notFound: return "HTTP/1.1 404 Not Found"
        case .requestTimeout: return "HTTP/1.1 408 Request Timeout"
        case .requestTooLarge: return "HTTP/1.1 413 Request Too Large"
        default: return "HTTP/1.1 500 Internal Server Error"
        }
    }
}

public enum HttpContentType: String {
    case arc = "arc"
    case avi = "avi"
    case azw = "azw"
    case bin = "bin"
    case bmp = "bmp"
    case bz = "bz"
    case bz2 = "bz2"
    case csh = "csh"
    case css = "css"
    case csv = "csv"
    case doc = "doc"
    case docx = "docx"
    case eot = "eot"
    case epub = "epub"
    case gz = "gz"
    case gif = "gif"
    case htm = "htm"
    case html = "html"
    case ico = "ico"
    case ics = "ics"
    case jar = "jar"
    case jpeg = "jpeg"
    case jpg = "jpg"
    case js = "js"
    case json = "json"
    case jsonld = "jsonld"
    case mid = "mid"
    case midi = "midi"
    case mjs = "mjs"
    case mp3 = "mp3"
    case mpeg = "mpeg"
    case mpkg = "mpkg"
    case odp = "odp"
    case ods = "ods"
    case odt = "odt"
    case oga = "oga"
    case ogv = "ogv"
    case ogx = "ogx"
    case opus = "opus"
    case otf = "otf"
    case png = "png"
    case pdf = "pdf"
    case php = "php"
    case ppt = "ppt"
    case pptx = "pptx"
    case rar = "rar"
    case rtf = "rtf"
    case sh = "sh"
    case svg = "svg"
    case swf = "swf"
    case tar = "tar"
    case tif = "tif"
    case tiff = "tiff"
    case ts = "ts"
    case ttf = "ttf"
    case txt = "txt"
    case vsd = "vsd"
    case wav = "wav"
    case weba = "weba"
    case webm = "webm"
    case webp = "webp"
    case woff = "woff"
    case woff2 = "woff2"
    case xhtml = "xhtml"
    case xls = "xls"
    case xlsx = "xlsx"
    case xml = "xml"
    case xul = "xul"
    case zip = "zip"
    case _3gp = "3gp"
    case _3g2 = "3g2"
    case _7z = "7z"

    static func fromPath(_ path: String) -> HttpContentType {
        let fileExt = (path as NSString).pathExtension
        if let type = HttpContentType(rawValue: fileExt) {
            return type
        }
        return .txt
    }

    var string: String {
        switch self {
        case .arc: return "application/x-freearc"
        case .avi: return "video/x-msvideo"
        case .azw: return "application/vnd.amazon.ebook"
        case .bin: return "application/octet-stream"
        case .bmp: return "image/bmp"
        case .bz: return  "application/x-bzip"
        case .bz2: return "application/x-bzip2"
        case .csh: return "application/x-csh"
        case .css: return "text/css"
        case .csv: return "text/csv"
        case .doc: return "application/msword"
        case .docx: return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case .eot: return "application/vnd.ms-fontobject"
        case .epub: return "application/epub+zip"
        case .gz: return  "application/gzip"
        case .gif: return "image/gif"
        case .htm: return "text/html"
        case .html: return "text/html"
        case .ico: return "image/vnd.microsoft.icon"
        case .ics: return "text/calendar"
        case .jar: return "application/java-archive"
        case .jpeg: return "image/jpeg"
        case .jpg: return "image/jpeg"
        case .js: return "text/javascript"
        case .json: return "application/json"
        case .jsonld: return "application/ld+json"
        case .mid: return "audio/midi"
        case .midi: return "audio/midi"
        case .mjs: return "text/javascript"
        case .mp3: return "audio/mpeg"
        case .mpeg: return "video/mpeg"
        case .mpkg: return "application/vnd.apple.installer+xml"
        case .odp: return "application/vnd.oasis.opendocument.presentation"
        case .ods: return "application/vnd.oasis.opendocument.spreadsheet"
        case .odt: return "application/vnd.oasis.opendocument.text"
        case .oga: return "audio/ogg"
        case .ogv: return "video/ogg"
        case .ogx: return "application/ogg"
        case .opus: return "audio/opus"
        case .otf: return "font/otf"
        case .png: return "image/png"
        case .pdf: return "application/pdf"
        case .php: return "application/php"
        case .ppt: return "application/vnd.ms-powerpoint"
        case .pptx: return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case .rar: return "application/x-rar-compressed"
        case .rtf: return "application/rtf"
        case .sh: return "application/x-sh"
        case .svg: return "image/svg+xml"
        case .swf: return "application/x-shockwave-flash"
        case .tar: return "application/x-tar"
        case .tif: return "image/tiff"
        case .tiff: return "image/tiff"
        case .ts: return "video/mp2t"
        case .ttf: return "font/ttf"
        case .txt: return "text/plain"
        case .vsd: return "application/vnd.visio"
        case .wav: return "audio/wav"
        case .weba: return "audio/webm"
        case .webm: return "video/webm"
        case .webp: return "image/webp"
        case .woff: return "font/woff"
        case .woff2: return "font/woff2"
        case .xhtml: return "application/xhtml+xml"
        case .xls: return "application/vnd.ms-excel"
        case .xlsx: return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case .xml: return "application/xml"
        case .xul: return "application/vnd.mozilla.xul+xml"
        case .zip: return "application/zip"
        case ._3gp: return "video/3gpp"
        case ._3g2: return "video/3gpp2"
        case ._7z: return "application/x-7z-compressed"
        }
    }
}
