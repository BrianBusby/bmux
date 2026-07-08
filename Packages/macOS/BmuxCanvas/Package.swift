// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxCanvas",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "BmuxCanvas",
            targets: ["BmuxCanvas"]
        ),
    ],
    targets: [
        .target(
            name: "BmuxCanvas",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxCanvasTests",
            dependencies: [
                "BmuxCanvas",
            ]
        ),
    ]
)
