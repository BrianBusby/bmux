// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxMobileShellUI",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "BmuxMobileShellUI",
            targets: ["BmuxMobileShellUI"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/BMUXMobileCore"),
        .package(path: "../../Shared/BmuxAgentChat"),
        .package(path: "../BmuxAgentChatUI"),
        .package(path: "../../Shared/BmuxAuthRuntime"),
        .package(path: "../BmuxMobileBrowser"),
        .package(path: "../BmuxMobileCamera"),
        .package(path: "../BmuxMobileDiagnostics"),
        .package(path: "../BmuxMobilePairedMac"),
        .package(path: "../BmuxMobileShell"),
        .package(path: "../BmuxMobileShellModel"),
        .package(path: "../BmuxMobileSupport"),
        .package(path: "../BmuxMobileTerminal"),
        .package(path: "../BmuxMobileTerminalKit"),
        .package(path: "../BmuxMobileWorkspace"),
        .package(path: "../../../vendor/stack-auth-swift-sdk-prerelease"),
    ],
    targets: [
        .target(
            name: "BmuxMobileShellUI",
            dependencies: [
                "BMUXMobileCore",
                "BmuxAgentChat",
                "BmuxAgentChatUI",
                "BmuxAuthRuntime",
                "BmuxMobileBrowser",
                "BmuxMobileCamera",
                "BmuxMobileDiagnostics",
                "BmuxMobilePairedMac",
                "BmuxMobileShell",
                "BmuxMobileShellModel",
                "BmuxMobileSupport",
                "BmuxMobileTerminal",
                "BmuxMobileTerminalKit",
                "BmuxMobileWorkspace",
                .product(name: "StackAuth", package: "stack-auth-swift-sdk-prerelease"),
            ],
            swiftSettings: [
                .define("BMUX_DEV_AUTH", .when(configuration: .debug)),
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "BmuxMobileShellUITests",
            dependencies: [
                "BMUXMobileCore",
                "BmuxMobilePairedMac",
                "BmuxMobileShellUI",
                "BmuxAgentChat",
                "BmuxMobileShell",
                "BmuxMobileShellModel",
                "BmuxMobileWorkspace",
                .product(name: "StackAuth", package: "stack-auth-swift-sdk-prerelease"),
            ],
            swiftSettings: [
                .define("BMUX_DEV_AUTH", .when(configuration: .debug)),
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
