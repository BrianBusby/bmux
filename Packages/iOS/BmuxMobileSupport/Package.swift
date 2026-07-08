// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxMobileSupport",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxMobileSupport",
            targets: ["BmuxMobileSupport"]
        ),
    ],
    targets: [
        .target(
            name: "BmuxMobileSupport",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxMobileSupportTests",
            dependencies: ["BmuxMobileSupport"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
