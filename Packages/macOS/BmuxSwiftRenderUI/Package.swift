// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxSwiftRenderUI",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxSwiftRenderUI",
            targets: ["BmuxSwiftRenderUI"]
        ),
    ],
    dependencies: [
        .package(path: "../BmuxSwiftRender"),
        .package(path: "../BmuxSettings"),
        .package(path: "../BmuxFoundation"),
    ],
    targets: [
        .target(
            name: "BmuxSwiftRenderUI",
            dependencies: [
                .product(name: "BmuxSwiftRender", package: "BmuxSwiftRender"),
                .product(name: "BmuxSettings", package: "BmuxSettings"),
                .product(name: "BmuxFoundation", package: "BmuxFoundation"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "BmuxSwiftRenderUITests",
            dependencies: ["BmuxSwiftRenderUI"]
        ),
    ]
)
