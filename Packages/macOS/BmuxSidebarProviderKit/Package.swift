// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BmuxSidebarProviderKit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxSidebarProviderKit",
            targets: ["BmuxSidebarProviderKit"]
        ),
    ],
    dependencies: [
        .package(path: "../BmuxFoundation"),
    ],
    targets: [
        .target(
            name: "BmuxSidebarProviderKit",
            dependencies: ["BmuxFoundation"]
        ),
    ]
)
