// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxMobileTerminalKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxMobileTerminalKit",
            targets: ["BmuxMobileTerminalKit"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/BMUXMobileCore"),
    ],
    targets: [
        .target(
            name: "BmuxMobileTerminalKit",
            dependencies: [
                "BMUXMobileCore",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxMobileTerminalKitTests",
            dependencies: ["BmuxMobileTerminalKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
