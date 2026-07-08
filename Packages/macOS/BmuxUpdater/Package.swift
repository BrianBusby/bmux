// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxUpdater",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxUpdater",
            targets: ["BmuxUpdater"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0"),
    ],
    targets: [
        .target(
            name: "BmuxUpdater",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxUpdaterTests",
            dependencies: [
                "BmuxUpdater",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
