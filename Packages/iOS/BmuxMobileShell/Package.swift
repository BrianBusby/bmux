// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxMobileShell",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxMobileShell",
            targets: ["BmuxMobileShell"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/BMUXMobileCore"),
        .package(path: "../../Shared/BmuxAgentChat"),
        .package(path: "../BmuxMobileDiagnostics"),
        .package(path: "../BmuxMobilePairedMac"),
        .package(path: "../BmuxMobileRPC"),
        .package(path: "../BmuxMobileShellModel"),
        .package(path: "../BmuxMobileSupport"),
        .package(path: "../BmuxMobileTransport"),
    ],
    targets: [
        .target(
            name: "BmuxMobileShell",
            dependencies: [
                "BMUXMobileCore",
                "BmuxAgentChat",
                "BmuxMobileDiagnostics",
                "BmuxMobilePairedMac",
                "BmuxMobileRPC",
                "BmuxMobileShellModel",
                "BmuxMobileSupport",
                "BmuxMobileTransport",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxMobileShellTests",
            dependencies: [
                "BmuxMobileShell",
                "BMUXMobileCore",
                "BmuxAgentChat",
                "BmuxMobilePairedMac",
                "BmuxMobileRPC",
                "BmuxMobileShellModel",
                "BmuxMobileTransport",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
