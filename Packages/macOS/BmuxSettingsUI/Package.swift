// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxSettingsUI",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxSettingsUI",
            targets: ["BmuxSettingsUI"]
        ),
    ],
    dependencies: [
        .package(path: "../BmuxFoundation"),
        .package(path: "../BmuxSettings"),
    ],
    targets: [
        .target(
            name: "BmuxSettingsUI",
            dependencies: [
                .product(name: "BmuxFoundation", package: "BmuxFoundation"),
                .product(name: "BmuxSettings", package: "BmuxSettings"),
            ]
        ),
        .testTarget(
            name: "BmuxSettingsUITests",
            dependencies: ["BmuxSettingsUI"]
        ),
    ]
)
