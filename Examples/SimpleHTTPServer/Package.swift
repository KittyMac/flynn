// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "SimpleHTTPServer",
    products: [
        .executable(name: "server", targets: ["SimpleHTTPServer"]),
        .library(name: "SimpleHTTPServerFramework", targets: ["SimpleHTTPServerFramework"])
    ],
    dependencies: [
        .package(url: "https://github.com/KittyMac/Flynn.git", branch: "SPM_Build_Tool"),
		.package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "1.0.0")),
		.package(url: "https://github.com/IBM-Swift/BlueSocket.git", .upToNextMinor(from: "1.0.0"))
    ],
    targets: [
        .executableTarget(
            name: "SimpleHTTPServer",
            dependencies: [
				"SimpleHTTPServerFramework",
				"Flynn",
                .product(name: "Socket", package: "BlueSocket"),
				.product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            plugins: [
                .plugin(name: "FlynnPlugin", package: "FlynnPlugin"),
            ]),
        .target(
            name: "SimpleHTTPServerFramework",
            dependencies: [
				"Flynn",
                .product(name: "Socket", package: "BlueSocket"),
				.product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
        .testTarget(
            name: "SimpleHTTPServerFrameworkTests",
            dependencies: [
                "SimpleHTTPServerFramework"
            ],
            exclude: [ ]
        )
    ]
)
