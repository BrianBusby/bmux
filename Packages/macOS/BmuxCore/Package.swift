// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxCore",
            targets: ["BmuxCore"]
        ),
    ],
    dependencies: [
        .package(path: "../BmuxFoundation"),
    ],
    targets: [
        .target(
            name: "BmuxCore",
            dependencies: [
                .product(name: "BmuxFoundation", package: "BmuxFoundation"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxCoreTests",
            dependencies: ["BmuxCore"]
        ),
    ]
)
