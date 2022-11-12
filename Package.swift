// swift-tools-version:5.6
import PackageDescription

// When runnning "make release" to build the binary tools change this to true
// Otherwise always set it to false
#if false
let productsTarget: [PackageDescription.Product] = [
    .executable(name: "FlynnPluginTool", targets: ["FlynnPluginTool"]),
    .library(name: "FlynnPluginFramework", targets: ["FlynnPluginFramework"]),
]
let pluginTarget: [PackageDescription.Target] = [
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
let pluginDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/jpsim/SourceKitten", exact: "0.32.0"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0")
]
#else
let productsTarget: [PackageDescription.Product] = [
    .library(name: "FlynnPluginTool", targets: ["FlynnPluginTool"]),
    .library(name: "FlynnPluginTool-focal", targets: ["FlynnPluginTool-focal"]),
    .library(name: "FlynnPluginTool-amazonlinux2", targets: ["FlynnPluginTool-amazonlinux2"]),
]
let pluginTarget: [PackageDescription.Target] = [
    .binaryTarget(name: "FlynnPluginTool",
                  path: "dist/FlynnPluginTool.zip"),
    .binaryTarget(name: "FlynnPluginTool-focal",
                  path: "dist/FlynnPluginTool-focal.zip"),
    .binaryTarget(name: "FlynnPluginTool-amazonlinux2",
                  path: "dist/FlynnPluginTool-amazonlinux2.zip"),
]
let pluginDependencies: [Package.Dependency] = [
    
]
#endif

let package = Package(
    name: "Flynn",
    platforms: [
        .iOS(.v9)
    ],
    products: productsTarget + [
        .library(name: "PonyLib", type: .dynamic, targets: ["Pony"]),
        .library(name: "Flynn", targets: ["Flynn"]),
        .plugin(name: "FlynnPlugin", targets: ["FlynnPlugin"]),
        .plugin(name: "FlynnPlugin-focal", targets: ["FlynnPlugin-focal"]),
        .plugin(name: "FlynnPlugin-amazonlinux2", targets: ["FlynnPlugin-amazonlinux2"]),
    ],
    dependencies: pluginDependencies + [
        
    ],
    targets: pluginTarget + [
        .target(
            name: "Pony",
            linkerSettings: [
                .linkedLibrary("atomic", .when(platforms: [.linux, .android]))
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
            dependencies: [ "FlynnPluginTool" ]
        ),
        .plugin(
            name: "FlynnPlugin-focal",
            capability: .buildTool(),
            dependencies: [ "FlynnPluginTool-focal" ]
        ),
        .plugin(
            name: "FlynnPlugin-amazonlinux2",
            capability: .buildTool(),
            dependencies: [ "FlynnPluginTool-amazonlinux2" ]
        ),
    ]
)
