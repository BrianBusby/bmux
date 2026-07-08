// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxRemoteDaemon",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxRemoteDaemon",
            targets: ["BmuxRemoteDaemon"]
        ),
    ],
    dependencies: [
        .package(path: "../BmuxFoundation"),
        .package(path: "../BmuxCore"),
    ],
    targets: [
        .target(
            name: "BmuxRemoteDaemon",
            dependencies: [
                .product(name: "BmuxFoundation", package: "BmuxFoundation"),
                .product(name: "BmuxCore", package: "BmuxCore"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxRemoteDaemonTests",
            dependencies: [
                "BmuxRemoteDaemon",
                .product(name: "BmuxCore", package: "BmuxCore"),
            ]
        ),
    ]
)
