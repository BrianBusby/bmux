// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxCommandPalette",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxCommandPalette",
            targets: ["BmuxCommandPalette"]
        ),
    ],
    dependencies: [
        // BmuxFoundation backs the FocusGuards/ command-palette focus-stealing
        // NSResponder/NSView guards.
        .package(path: "../BmuxFoundation"),
    ],
    targets: [
        .target(
            name: "BmuxCommandPalette",
            dependencies: [
                .product(name: "BmuxFoundation", package: "BmuxFoundation"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxCommandPaletteTests",
            dependencies: [
                "BmuxCommandPalette",
                .product(name: "BmuxFoundation", package: "BmuxFoundation"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
