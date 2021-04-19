// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "Flynn",
    platforms: [
        .iOS(.v9)
    ],
    products: [
        .library(name: "Flynn", targets: ["Flynn"])
    ],
    dependencies: [
        .package(url: "https://github.com/KittyMac/BinaryCodable.git", .branch("develop")),
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
            dependencies: [ "Pony", "BinaryCodable" ]
        ),
        .testTarget(
            name: "FlynnTests",
            dependencies: [ "Flynn" ],
            exclude: [ "Resources" ]
        )

    ]
)
