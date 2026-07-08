// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StubAgentSidebarExtension",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "StubAgentSidebarExtension",
            targets: ["StubAgentSidebarExtension"]
        ),
    ],
    dependencies: [
        .package(path: "../../Packages/macOS/BmuxExtensionKit"),
    ],
    targets: [
        .target(
            name: "StubAgentSidebarExtension",
            dependencies: [
                .product(name: "BmuxExtensionKit", package: "BmuxExtensionKit"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
