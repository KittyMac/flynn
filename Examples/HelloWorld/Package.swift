// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "HelloWorld",
    dependencies: [
        .package(path: "../../")
    ],
    targets: [
        .executableTarget(
            name: "HelloWorld",
            dependencies: [
                "Flynn"
            ],
            plugins: [
                .plugin(name: "FlynnPlugin", package: "Flynn"),
            ]
        )
    ]
)
