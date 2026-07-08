// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxSettings",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxSettings",
            targets: ["BmuxSettings"]
        ),
    ],
    dependencies: [
        .package(path: "../BmuxFoundation"),
    ],
    targets: [
        .target(
            name: "BmuxSettings",
            dependencies: [
                .product(name: "BmuxFoundation", package: "BmuxFoundation"),
            ]
        ),
        .testTarget(
            name: "BmuxSettingsTests",
            dependencies: ["BmuxSettings"]
        ),
    ]
)
