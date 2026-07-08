// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxMobileWorkspace",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxMobileWorkspace",
            targets: ["BmuxMobileWorkspace"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/BMUXMobileCore"),
        .package(path: "../BmuxMobileShellModel"),
    ],
    targets: [
        .target(
            name: "BmuxMobileWorkspace",
            dependencies: [
                "BMUXMobileCore",
                "BmuxMobileShellModel",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxMobileWorkspaceTests",
            dependencies: ["BmuxMobileWorkspace"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
