// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxCanvasUI",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxCanvasUI",
            targets: ["BmuxCanvasUI"]
        ),
    ],
    dependencies: [
        .package(path: "../BmuxCanvas"),
        .package(path: "../BmuxFoundation"),
    ],
    targets: [
        .target(
            name: "BmuxCanvasUI",
            dependencies: [
                "BmuxCanvas",
                "BmuxFoundation",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxCanvasUITests",
            dependencies: [
                "BmuxCanvasUI",
            ]
        ),
    ]
)
