// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxRemoteSession",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxRemoteSession",
            targets: ["BmuxRemoteSession"]
        ),
    ],
    dependencies: [
        .package(path: "../BmuxFoundation"),
        .package(path: "../BmuxCore"),
        .package(path: "../BmuxRemoteDaemon"),
        .package(path: "../BmuxRemoteWorkspace"),
        .package(path: "../BMUXDebugLog"),
    ],
    targets: [
        .target(
            name: "BmuxRemoteSession",
            dependencies: [
                .product(name: "BmuxFoundation", package: "BmuxFoundation"),
                .product(name: "BmuxCore", package: "BmuxCore"),
                .product(name: "BmuxRemoteDaemon", package: "BmuxRemoteDaemon"),
                .product(name: "BmuxRemoteWorkspace", package: "BmuxRemoteWorkspace"),
                .product(name: "BMUXDebugLog", package: "BMUXDebugLog"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxRemoteSessionTests",
            dependencies: [
                "BmuxRemoteSession",
                .product(name: "BmuxCore", package: "BmuxCore"),
                .product(name: "BmuxRemoteDaemon", package: "BmuxRemoteDaemon"),
                .product(name: "BmuxRemoteWorkspace", package: "BmuxRemoteWorkspace"),
            ]
        ),
    ]
)
