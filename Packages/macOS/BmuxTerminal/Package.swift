// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxTerminal",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxTerminal",
            targets: ["BmuxTerminal"]
        ),
    ],
    dependencies: [
        .package(path: "../BmuxTerminalCore"),
        .package(path: "../BMUXDebugLog"),
        .package(path: "../BMUXAgentLaunch"),
        .package(path: "../../Shared/BMUXMobileCore"),
        .package(path: "../../../vendor/bonsplit"),
    ],
    targets: [
        .target(
            name: "BmuxTerminal",
            dependencies: [
                .product(name: "BmuxTerminalCore", package: "BmuxTerminalCore"),
                .product(name: "BmuxGhosttyKit", package: "BmuxTerminalCore"),
                .product(name: "BMUXDebugLog", package: "BMUXDebugLog"),
                .product(name: "BMUXAgentLaunch", package: "BMUXAgentLaunch"),
                .product(name: "BMUXMobileCore", package: "BMUXMobileCore"),
                .product(name: "Bonsplit", package: "bonsplit"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        // Test-only stand-in for the @_silgen_name libghostty symbol bound by
        // BmuxTerminalCore's GhosttyRuntimeCInterop: SwiftPM cannot link the
        // GhosttyKit macOS archive (its binary lacks the lib prefix), so the
        // test runner satisfies the link with a stub. The app links the real
        // GhosttyKit.
        .target(
            name: "GhosttyRuntimeTestStubs",
            path: "Tests/GhosttyRuntimeTestStubs"
        ),
        .testTarget(
            name: "BmuxTerminalTests",
            dependencies: [
                "BmuxTerminal",
                "GhosttyRuntimeTestStubs",
                .product(name: "BmuxTerminalCore", package: "BmuxTerminalCore"),
                .product(name: "BmuxGhosttyKit", package: "BmuxTerminalCore"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
