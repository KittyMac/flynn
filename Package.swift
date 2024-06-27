// swift-tools-version:5.6
import PackageDescription

// When runnning "make release" to build the binary tools change this to true
// Otherwise always set it to false
#if false
let productsTarget: [PackageDescription.Product] = [
]
let pluginTarget: [PackageDescription.Target] = [
    .executableTarget(
        name: "FlynnPluginTool-focal",
        dependencies: ["FlynnPluginFramework"]
    ),
    .plugin(
        name: "FlynnPlugin",
        capability: .buildTool(),
        dependencies: [
            "FlynnPluginTool-focal"
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
pluginDependencies.append(.package(url: "https://github.com/jpsim/SourceKitten", exact: "0.32.0"))
#endif

#else

var plugins = [
    "FlynnPluginTool-focal",
    "FlynnPluginTool-amazonlinux2",
    "FlynnPluginTool-fedora",
    "FlynnPluginTool-fedora38",
]

#if os(Windows)
plugins += [
    "FlynnPluginTool-windows"
]
#endif

var productsTarget: [PackageDescription.Product] = [
    .library(name: "FlynnPluginTool", targets: plugins),
]
var pluginTarget: [PackageDescription.Target] = [
    .binaryTarget(name: "FlynnPluginTool-focal",
                  path: "dist/FlynnPluginTool-focal.zip"),
    .binaryTarget(name: "FlynnPluginTool-amazonlinux2",
                  path: "dist/FlynnPluginTool-amazonlinux2.zip"),
    .binaryTarget(name: "FlynnPluginTool-fedora",
                  path: "dist/FlynnPluginTool-fedora.zip"),
    .binaryTarget(name: "FlynnPluginTool-fedora38",
                  path: "dist/FlynnPluginTool-fedora38.zip"),
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
    .binaryTarget(name: "FlynnPluginTool-windows",
                  path: "dist/FlynnPluginTool-windows.zip")
]
#endif

#endif

let package = Package(
    name: "Flynn",
    platforms: [
        .iOS(.v9)
    ],
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
