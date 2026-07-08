// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxFoundation",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxFoundation",
            targets: ["BmuxFoundation"]
        ),
    ],
    targets: [
        .target(
            name: "BmuxFoundation",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxFoundationTests",
            dependencies: ["BmuxFoundation"]
        ),
    ]
)
