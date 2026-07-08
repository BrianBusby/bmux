// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxClientConfig",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxClientConfig",
            targets: ["BmuxClientConfig"]
        ),
    ],
    targets: [
        .target(
            name: "BmuxClientConfig",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "BmuxClientConfigTests",
            dependencies: ["BmuxClientConfig"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
