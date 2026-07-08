// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BMUXAuthCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BMUXAuthCore",
            targets: ["BMUXAuthCore"]
        ),
    ],
    targets: [
        .target(
            name: "BMUXAuthCore"
        ),
        .testTarget(
            name: "BMUXAuthCoreTests",
            dependencies: ["BMUXAuthCore"]
        ),
    ]
)
