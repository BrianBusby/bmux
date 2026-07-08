// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxMobileTerminal",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "BmuxMobileTerminal",
            targets: ["BmuxMobileTerminal"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/BMUXMobileCore"),
        .package(path: "../BmuxMobileDiagnostics"),
        .package(path: "../BmuxMobileSupport"),
        .package(path: "../BmuxMobileTerminalKit"),
    ],
    targets: [
        // The same libghostty the Mac links; iOS feeds raw PTY bytes straight
        // into ghostty_surface_* so the phone runs the identical terminal core.
        .binaryTarget(
            name: "GhosttyKit",
            path: "../../../GhosttyKit.xcframework"
        ),
        .target(
            name: "BmuxMobileTerminal",
            dependencies: [
                "BMUXMobileCore",
                "BmuxMobileDiagnostics",
                "BmuxMobileSupport",
                "BmuxMobileTerminalKit",
                "GhosttyKit",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
