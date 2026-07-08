// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxAppKitSupportUI",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxAppKitSupportUI",
            targets: ["BmuxAppKitSupportUI"]
        ),
    ],
    dependencies: [
        .package(path: "../BmuxFoundation"),
        .package(path: "../BmuxWorkspaces"),
    ],
    targets: [
        .target(
            name: "BmuxAppKitSupportUI",
            dependencies: [
                "BmuxFoundation",
                "BmuxWorkspaces",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxAppKitSupportUITests",
            dependencies: ["BmuxAppKitSupportUI"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
