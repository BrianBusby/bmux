// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxWindowing",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxWindowing",
            targets: ["BmuxWindowing"]
        ),
    ],
    targets: [
        .target(
            name: "BmuxWindowing",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxWindowingTests",
            dependencies: ["BmuxWindowing"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
