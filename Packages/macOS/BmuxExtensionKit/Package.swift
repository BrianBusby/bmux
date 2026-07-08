// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BmuxExtensionKit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxExtensionKit",
            targets: ["BmuxExtensionKit"]
        ),
    ],
    targets: [
        .target(
            name: "BmuxExtensionKit"
        ),
        .testTarget(
            name: "BmuxExtensionKitTests",
            dependencies: ["BmuxExtensionKit"]
        ),
    ]
)
