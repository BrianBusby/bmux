// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxMobilePairedMac",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxMobilePairedMac",
            targets: ["BmuxMobilePairedMac"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/BMUXMobileCore"),
    ],
    targets: [
        .target(
            name: "BmuxMobilePairedMac",
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
            name: "BmuxMobilePairedMacTests",
            dependencies: ["BmuxMobilePairedMac"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
