// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxNotifications",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxNotifications",
            targets: ["BmuxNotifications"]
        ),
    ],
    targets: [
        .target(
            name: "BmuxNotifications",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxNotificationsTests",
            dependencies: ["BmuxNotifications"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
