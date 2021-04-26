// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if os(Linux)
    let flynnPackage = Package.Dependency.package(url: "https://github.com/KittyMac/Flynn.git", .branch("cluster_archiver"))
#else
    let flynnPackage = Package.Dependency.package(name: "Flynn", path: "../../")
#endif

let package = Package(
    name: "ClusterArchiver",
    platforms: [
        .macOS(.v10_12)
    ],
    products: [
        .executable(name: "ClusterArchiver", targets: ["ClusterArchiver"]),
        .library(name: "ClusterArchiverFramework", targets: ["ClusterArchiverFramework"])
    ],
    dependencies: [
        flynnPackage,
        .package(url: "https://github.com/KittyMac/BinaryCodable.git", .branch("develop")),
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
                "LzSwift",
                "BinaryCodable"
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
