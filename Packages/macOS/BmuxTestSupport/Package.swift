// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxTestSupport",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxTestSupport",
            targets: ["BmuxTestSupport"]
        ),
    ],
    targets: [
        .target(
            name: "BmuxTestSupport",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxTestSupportTests",
            dependencies: ["BmuxTestSupport"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
