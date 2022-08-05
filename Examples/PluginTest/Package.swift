// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "PluginTest",
    dependencies: [
        .package(path: "../../")
    ],
    targets: [
        .executableTarget(
            name: "PluginTest",
            dependencies: [
                "Flynn"
            ],
            plugins: [
                .plugin(name: "FlynnPlugin", package: "Flynn"),
            ]),
        .testTarget(
            name: "PluginTestTests",
            dependencies: ["PluginTest"]),
    ]
)
