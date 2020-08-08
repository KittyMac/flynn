// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SimpleHTTPServer",
    products: [
        .executable(name: "server", targets: ["SimpleHTTPServer"]),
        .library(name: "SimpleHTTPServerFramework", targets: ["SimpleHTTPServerFramework"])
    ],
    dependencies: [
        .package(url: "https://github.com/KittyMac/Flynn.git", .branch("ponyrt_v2")),
		.package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.2.0")),
		.package(name: "Socket", url: "https://github.com/IBM-Swift/BlueSocket.git", .upToNextMinor(from: "1.0.0"))
    ],
    targets: [
        .target(
            name: "SimpleHTTPServer",
            dependencies: [
				"SimpleHTTPServerFramework",
				"Socket",
				"Flynn",
				.product(name: "ArgumentParser", package: "swift-argument-parser") ]),
        .target(
            name: "SimpleHTTPServerFramework",
            dependencies: [
				"Socket",
				"Flynn",
				.product(name: "ArgumentParser", package: "swift-argument-parser") ]),
        .testTarget(
            name: "SimpleHTTPServerFrameworkTests",
            dependencies: [
                "SimpleHTTPServerFramework"
            ],
            exclude: [
                "Resources"
            ]
        )
    ]
)
