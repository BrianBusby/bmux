// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxExtensionSidebarExamples",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "BmuxExtensionSidebarExamples",
            targets: ["BmuxExtensionSidebarExamples"]
        ),
    ],
    dependencies: [
        .package(path: "../../Packages/macOS/BmuxSidebarProviderKit"),
    ],
    targets: [
        .target(
            name: "BmuxExtensionSidebarExamples",
            dependencies: ["BmuxSidebarProviderKit"]
        ),
        .testTarget(
            name: "BmuxExtensionSidebarExamplesTests",
            dependencies: ["BmuxExtensionSidebarExamples"]
        ),
    ]
)
