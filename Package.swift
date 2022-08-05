// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "Flynn",
    platforms: [
        .iOS(.v9)
    ],
    products: [
        .library(name: "Flynn", targets: ["Flynn"]),
        .executable(name: "FlynnLint", targets: ["FlynnLint"]),
        .plugin(name: "FlynnPlugin", targets: ["FlynnPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/SourceKitten", from: "0.32.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "Pony",
            linkerSettings: [
                .linkedLibrary("atomic", .when(platforms: [.linux]))
            ]
        ),
        .target(
            name: "Flynn",
            dependencies: [ "Pony" ]
        ),
        .testTarget(
            name: "FlynnTests",
            dependencies: [ "Flynn" ],
            exclude: [ "Resources" ]
        ),
        
        .plugin(
            name: "FlynnPlugin",
            capability: .buildTool(),
            dependencies: ["FlynnLint", "FlynnLintFramework"]
        ),
        
        .executableTarget(
            name: "FlynnLint",
            dependencies: ["FlynnLintFramework"]
        ),
        .target(
            name: "FlynnLintFramework",
            dependencies: [
                .product(name: "SourceKittenFramework", package: "SourceKitten"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "Flynn"
            ]
        ),
        .testTarget(
            name: "FlynnLintFrameworkTests",
            dependencies: [ "FlynnLintFramework" ],
            exclude: [ "Resources" ]
        )

    ]
)
