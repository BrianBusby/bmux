// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxPanes",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxPanes",
            targets: ["BmuxPanes"]
        ),
    ],
    dependencies: [
        .package(path: "../../../vendor/bonsplit"),
    ],
    targets: [
        .target(
            name: "BmuxPanes",
            dependencies: [
                .product(name: "Bonsplit", package: "bonsplit"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxPanesTests",
            dependencies: ["BmuxPanes"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
