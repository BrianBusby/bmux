// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxLiveEval",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxLiveEval",
            targets: ["BmuxLiveEval"]
        ),
        .executable(
            name: "LiveEvalDemo",
            targets: ["LiveEvalDemo"]
        ),
    ],
    dependencies: [
        .package(path: "../BmuxSwiftRender"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        .target(
            name: "BmuxLiveEval",
            dependencies: [
                .product(name: "BmuxSwiftRender", package: "BmuxSwiftRender"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftOperators", package: "swift-syntax"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .executableTarget(
            name: "LiveEvalDemo",
            dependencies: ["BmuxLiveEval"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "BmuxLiveEvalTests",
            dependencies: ["BmuxLiveEval"]
        ),
    ]
)
