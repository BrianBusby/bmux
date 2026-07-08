// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxControlSocket",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxControlSocket",
            targets: ["BmuxControlSocket"]
        ),
    ],
    dependencies: [
        .package(path: "../BmuxSettings"),
    ],
    targets: [
        .target(
            name: "BmuxControlSocket",
            dependencies: [
                .product(name: "BmuxSettings", package: "BmuxSettings"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxControlSocketTests",
            dependencies: [
                "BmuxControlSocket",
                .product(name: "BmuxSettings", package: "BmuxSettings"),
            ]
        ),
    ]
)
