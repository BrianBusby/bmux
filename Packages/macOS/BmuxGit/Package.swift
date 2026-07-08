// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxGit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxGit",
            targets: ["BmuxGit"]
        ),
    ],
    dependencies: [
        .package(path: "../BmuxFoundation"),
    ],
    targets: [
        .target(
            name: "BmuxGit",
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
            name: "BmuxGitTests",
            dependencies: ["BmuxGit"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
