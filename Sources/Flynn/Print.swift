import Foundation

@usableFromInline
func print(_ items: Any..., separator: String = " ", terminator: String = "\n", truncate: Int) {
    let output = items.map { "\($0)" }.joined(separator: separator)
    Flynn.syslog("Flynn", output)
}

@usableFromInline
func print(tag: String, _ items: Any..., separator: String = " ", terminator: String = "\n", truncate: Int) {
    let output = items.map { "\($0)" }.joined(separator: separator)
    Flynn.syslog(tag, output)
}

@usableFromInline
func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    print(items, separator: separator, terminator: terminator, truncate: 4096)
}

@usableFromInline
func print(tag: String, _ items: Any..., separator: String = " ", terminator: String = "\n") {
    print(tag: tag, items, separator: separator, terminator: terminator, truncate: 4096)
}
