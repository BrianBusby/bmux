// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxMobileShellModel",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxMobileShellModel",
            targets: ["BmuxMobileShellModel"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/BMUXMobileCore"),
    ],
    targets: [
        .target(
            name: "BmuxMobileShellModel",
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
            name: "BmuxMobileShellModelTests",
            dependencies: ["BmuxMobileShellModel"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
