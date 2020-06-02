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
    ],
    targets: [
        .target(
            name: "Pony",
			cSettings: [
			        .headerSearchPath("Sources/PonyRT")
			    ]
        ),
        .target(
            name: "Flynn",
            dependencies: [
				"Pony"
            ]
        ),
        .testTarget(
            name: "FlynnTests",
            dependencies: [
                "Flynn",
				"Pony"
            ],
            exclude: [
                "Resources"
            ]
        )
    ]
)
