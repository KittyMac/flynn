// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ClusterCounter",
    platforms: [
        .macOS(.v10_12)
    ],
    products: [
        .executable(name: "server", targets: ["ClusterCounter"]),
        .library(name: "ClusterCounterFramework", targets: ["ClusterCounterFramework"])
    ],
    dependencies: [
        .package(url: "https://github.com/KittyMac/Flynn.git", .branch("remote_actors")),
		.package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.2.0")),
    ],
    targets: [
        .target(
            name: "ClusterCounter",
            dependencies: [
				"ClusterCounterFramework",
				.product(name: "ArgumentParser", package: "swift-argument-parser") ]),
        .target(
            name: "ClusterCounterFramework",
            dependencies: [
				"Flynn"
			]),
        .testTarget(
            name: "ClusterCounterFrameworkTests",
            dependencies: [
                "ClusterCounterFramework"
            ],
            exclude: [
                "Resources"
            ]
        )
    ]
)
