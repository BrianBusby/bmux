// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxRemoteWorkspace",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxRemoteWorkspace",
            targets: ["BmuxRemoteWorkspace"]
        ),
    ],
    dependencies: [
        .package(path: "../BmuxFoundation"),
        .package(path: "../BmuxCore"),
        .package(path: "../BmuxRemoteDaemon"),
        .package(path: "../BmuxSettings"),
    ],
    targets: [
        .target(
            name: "BmuxRemoteWorkspace",
            dependencies: [
                .product(name: "BmuxFoundation", package: "BmuxFoundation"),
                .product(name: "BmuxCore", package: "BmuxCore"),
                .product(name: "BmuxRemoteDaemon", package: "BmuxRemoteDaemon"),
                .product(name: "BmuxSettings", package: "BmuxSettings"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxRemoteWorkspaceTests",
            dependencies: ["BmuxRemoteWorkspace"]
        ),
    ]
)
