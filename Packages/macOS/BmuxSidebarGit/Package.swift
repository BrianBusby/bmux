// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxSidebarGit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxSidebarGit",
            targets: ["BmuxSidebarGit"]
        ),
    ],
    dependencies: [
        .package(path: "../BmuxGit"),
        .package(path: "../BmuxFoundation"),
    ],
    targets: [
        .target(
            name: "BmuxSidebarGit",
            dependencies: [
                .product(name: "BmuxGit", package: "BmuxGit"),
                .product(name: "BmuxFoundation", package: "BmuxFoundation"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxSidebarGitTests",
            dependencies: [
                "BmuxSidebarGit",
                .product(name: "BmuxGit", package: "BmuxGit"),
                .product(name: "BmuxFoundation", package: "BmuxFoundation"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
