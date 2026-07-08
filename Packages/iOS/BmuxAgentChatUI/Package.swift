// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxAgentChatUI",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxAgentChatUI",
            targets: ["BmuxAgentChatUI"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/BmuxAgentChat"),
        .package(path: "../BmuxMobileSupport"),
    ],
    targets: [
        .target(
            name: "BmuxAgentChatUI",
            dependencies: [
                "BmuxAgentChat",
                "BmuxMobileSupport",
            ],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "BmuxAgentChatUITests",
            dependencies: ["BmuxAgentChatUI"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
