// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxAuthRuntime",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxAuthRuntime",
            targets: ["BmuxAuthRuntime"]
        ),
    ],
    dependencies: [
        .package(path: "../BMUXAuthCore"),
        .package(path: "../../../vendor/stack-auth-swift-sdk-prerelease"),
    ],
    targets: [
        .target(
            name: "BmuxAuthRuntime",
            dependencies: [
                "BMUXAuthCore",
                .product(name: "StackAuth", package: "stack-auth-swift-sdk-prerelease"),
            ],
            swiftSettings: [
                .define("BMUX_DEV_AUTH", .when(configuration: .debug)),
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxAuthRuntimeTests",
            dependencies: ["BmuxAuthRuntime"],
            swiftSettings: [
                .define("BMUX_DEV_AUTH", .when(configuration: .debug)),
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
