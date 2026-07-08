// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxSyncStore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxSyncStore",
            targets: ["BmuxSyncStore"]
        ),
    ],
    dependencies: [
        .package(path: "../BMUXMobileCore"),
        .package(path: "../../iOS/BmuxMobilePairedMac"),
        .package(path: "../../iOS/BmuxMobileShellModel"),
    ],
    targets: [
        .target(
            name: "BmuxSyncStore",
            dependencies: [
                "BMUXMobileCore",
                "BmuxMobilePairedMac",
                "BmuxMobileShellModel",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxSyncStoreTests",
            dependencies: ["BmuxSyncStore", "BmuxMobilePairedMac", "BMUXMobileCore", "BmuxMobileShellModel"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
