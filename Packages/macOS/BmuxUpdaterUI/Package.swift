// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxUpdaterUI",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxUpdaterUI",
            targets: ["BmuxUpdaterUI"]
        ),
    ],
    dependencies: [
        .package(path: "../BmuxFoundation"),
        .package(path: "../BmuxUpdater"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0"),
    ],
    targets: [
        .target(
            name: "BmuxUpdaterUI",
            dependencies: [
                "BmuxFoundation",
                "BmuxUpdater",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxUpdaterUITests",
            dependencies: ["BmuxUpdaterUI"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
