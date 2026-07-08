// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BMUXDebugLog",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "BMUXDebugLog",
            targets: ["BMUXDebugLog"]
        ),
    ],
    targets: [
        .target(
            name: "BMUXDebugLog",
            path: "Sources/BMUXDebugLog"
        ),
        .testTarget(
            name: "BMUXDebugLogTests",
            dependencies: ["BMUXDebugLog"],
            path: "Tests/BMUXDebugLogTests"
        ),
    ]
)
