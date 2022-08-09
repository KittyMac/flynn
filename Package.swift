// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "Flynn",
    platforms: [
        .iOS(.v9)
    ],
    products: [
        .executable(name: "FlynnPluginTool", targets: ["FlynnPluginTool"]),
        .library(name: "FlynnPluginFramework", targets: ["FlynnPluginFramework"]),
        .library(name: "Flynn", targets: ["Flynn"]),
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
            dependencies: [ "Pony" ],
            plugins: [
                .plugin(name: "FlynnPlugin")
            ]
        ),
        .testTarget(
            name: "FlynnTests",
            dependencies: [ "Flynn" ],
            plugins: [
                .plugin(name: "FlynnPlugin")
            ]
        ),
        
        .plugin(
            name: "FlynnPlugin",
            capability: .buildTool(),
            dependencies: ["FlynnPluginTool"]
        ),
                
        .executableTarget(
            name: "FlynnPluginTool",
            dependencies: ["FlynnPluginFramework"]
        ),
        .target(
            name: "FlynnPluginFramework",
            dependencies: [
                .product(name: "SourceKittenFramework", package: "SourceKitten"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "FlynnPluginFrameworkTests",
            dependencies: [ "FlynnPluginFramework" ]
        )

    ]
)
