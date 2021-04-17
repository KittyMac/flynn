// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ClusterArchiver",
    platforms: [
        .macOS(.v10_12)
    ],
    products: [
        .executable(name: "server", targets: ["ClusterArchiver"]),
        .library(name: "ClusterArchiverFramework", targets: ["ClusterArchiverFramework"])
    ],
    dependencies: [
		.package(name: "Flynn", path: "../../"),
        .package(url: "https://github.com/KittyMac/LzSwift.git", .branch("vendored")),
		.package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.2.0")),
    ],
    targets: [
        .target(
            name: "ClusterArchiver",
            dependencies: [
				"ClusterArchiverFramework",
				.product(name: "ArgumentParser", package: "swift-argument-parser") ]),
        .target(
            name: "ClusterArchiverFramework",
            dependencies: [
				"Flynn",
                "LzSwift"
			]),
        .testTarget(
            name: "ClusterArchiverFrameworkTests",
            dependencies: [
                "ClusterArchiverFramework"
            ],
            exclude: [
                "Resources"
            ]
        )
    ]
)
