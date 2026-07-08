// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxMobileTransport",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxMobileTransport",
            targets: ["BmuxMobileTransport"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/BMUXMobileCore"),
    ],
    targets: [
        .target(
            name: "BmuxMobileTransport",
            dependencies: ["BMUXMobileCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxMobileTransportTests",
            dependencies: ["BmuxMobileTransport", "BMUXMobileCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
