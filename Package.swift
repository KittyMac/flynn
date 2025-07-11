// swift-tools-version:5.6
import PackageDescription

// When runnning "make release" to build the binary tools change this to true
// Otherwise always set it to false
#if false
let platforms: [PackageDescription.SupportedPlatform]? = [ .macOS(.v12) ]
let productsTarget: [PackageDescription.Product] = [
]
let pluginTarget: [PackageDescription.Target] = [
    .executableTarget(
        name: "FlynnPluginTool",
        dependencies: ["FlynnPluginFramework"]
    ),
    .plugin(
        name: "FlynnPlugin",
        capability: .buildTool(),
        dependencies: [
            "FlynnPluginTool"
        ]
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
var pluginDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0")
]
#if os(Windows)
pluginDependencies.append(.package(url: "https://github.com/compnerd/SourceKitten", branch: "windows"))
#else
pluginDependencies.append(.package(url: "https://github.com/jpsim/SourceKitten", exact: "0.37.2"))
#endif

#else
let platforms: [PackageDescription.SupportedPlatform]? = nil

var plugins = [
    "FlynnPluginTool-focal-571",
    "FlynnPluginTool-focal-580",
    "FlynnPluginTool-focal-592",
    "FlynnPluginTool-jammy-592",
    "FlynnPluginTool-fedora38-573",
]

#if os(Windows)
plugins += [
    "FlynnPluginTool-windows-592"
]
#endif

var productsTarget: [PackageDescription.Product] = [
    .library(name: "FlynnPluginTool", targets: plugins),
]
var pluginTarget: [PackageDescription.Target] = [
    .binaryTarget(name: "FlynnPluginTool-focal-571",
                  path: "dist/FlynnPluginTool-focal-571.zip"),
    .binaryTarget(name: "FlynnPluginTool-fedora38-573",
                  path: "dist/FlynnPluginTool-fedora38-573.zip"),
    .binaryTarget(name: "FlynnPluginTool-focal-580",
                  path: "dist/FlynnPluginTool-focal-580.zip"),
    .binaryTarget(name: "FlynnPluginTool-focal-592",
                  path: "dist/FlynnPluginTool-focal-592.zip"),
    .binaryTarget(name: "FlynnPluginTool-jammy-592",
                  path: "dist/FlynnPluginTool-jammy-592.zip"),
    .plugin(
        name: "FlynnPlugin",
        capability: .buildTool(),
        dependencies: plugins.map({ Target.Dependency(stringLiteral: $0) })
    ),
]
var pluginDependencies: [Package.Dependency] = [
    
]

#if os(Windows)
pluginTarget += [
    .binaryTarget(name: "FlynnPluginTool-windows-592",
                  path: "dist/FlynnPluginTool-windows-592.zip")
]
#endif

#endif

let package = Package(
    name: "Flynn",
    platforms: platforms,
    products: productsTarget + [
        .library(name: "Flynn", targets: ["Flynn"]),
        .library(name: "PonyLib", type: .dynamic, targets: ["Pony"]),
        .plugin(name: "FlynnPlugin", targets: ["FlynnPlugin"]),
    ],
    dependencies: pluginDependencies + [
        
    ],
    targets: pluginTarget + [
        .target(
            name: "Pony",
            linkerSettings: [
                .linkedLibrary("atomic", .when(platforms: [.linux, .android])),
                .linkedLibrary("resolv", .when(platforms: [.linux, .macOS, .iOS])),
                .linkedLibrary("swiftCore", .when(platforms: [.windows])),
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
    ]
)
