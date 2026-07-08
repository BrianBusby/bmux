// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxMobileRPC",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxMobileRPC",
            targets: ["BmuxMobileRPC"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/BMUXMobileCore"),
        .package(path: "../BmuxMobileShellModel"),
        .package(path: "../BmuxMobileSupport"),
    ],
    targets: [
        .target(
            name: "BmuxMobileRPC",
            dependencies: [
                "BMUXMobileCore",
                "BmuxMobileShellModel",
                "BmuxMobileSupport",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxMobileRPCTests",
            dependencies: [
                "BmuxMobileRPC",
                "BMUXMobileCore",
                "BmuxMobileShellModel",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
