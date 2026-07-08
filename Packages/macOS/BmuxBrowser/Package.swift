// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxBrowser",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxBrowser",
            targets: ["BmuxBrowser"]
        ),
    ],
    dependencies: [
        .package(path: "../../../vendor/bonsplit"),
    ],
    targets: [
        .target(
            name: "BmuxBrowser",
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
            name: "BmuxBrowserTests",
            dependencies: ["BmuxBrowser"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
