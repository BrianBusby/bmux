// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxAgentChat",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxAgentChat",
            targets: ["BmuxAgentChat"]
        ),
    ],
    targets: [
        .target(
            name: "BmuxAgentChat",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "BmuxAgentChatTests",
            dependencies: ["BmuxAgentChat"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
