// swift-tools-version:5.0
import PackageDescription

let supportsPonyRT: BuildSettingCondition = .when(platforms: [.iOS, .macOS, .tvOS, .watchOS])

let package = Package(
    name: "Flynn",
    platforms: [
        .iOS(.v9)
    ],
    products: [
		.library(name: "Pony", targets: ["Pony"]),
        .library(name: "Flynn", targets: ["Flynn"])
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Pony",
			cSettings: [
				.define("PLATFORM_SUPPORTS_PONYRT", supportsPonyRT)
		    ],
			cxxSettings: [
				.define("PLATFORM_SUPPORTS_PONYRT", supportsPonyRT)
		    ]
        ),
        .target(
            name: "Flynn",
            dependencies: [
				"Pony"
            ],
			cSettings: [
				.define("PLATFORM_SUPPORTS_PONYRT", supportsPonyRT)
		    ],
			cxxSettings: [
				.define("PLATFORM_SUPPORTS_PONYRT", supportsPonyRT)
		    ],
			swiftSettings: [
				.define("PLATFORM_SUPPORTS_PONYRT", supportsPonyRT)
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
