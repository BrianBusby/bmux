// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxSidebar",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxSidebar",
            targets: ["BmuxSidebar"]
        ),
    ],
    dependencies: [
        .package(path: "../BmuxFoundation"),
        .package(path: "../BmuxSwiftRender"),
        // BmuxExtensionKit backs the ExtensionHost/ sidebar-extension host view
        // and browser presenter.
        .package(path: "../BmuxExtensionKit"),
    ],
    targets: [
        .target(
            name: "BmuxSidebar",
            dependencies: [
                .product(name: "BmuxFoundation", package: "BmuxFoundation"),
                .product(name: "BmuxSwiftRender", package: "BmuxSwiftRender"),
                .product(name: "BmuxExtensionKit", package: "BmuxExtensionKit"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxSidebarTests",
            dependencies: [
                "BmuxSidebar",
                .product(name: "BmuxFoundation", package: "BmuxFoundation"),
                .product(name: "BmuxSwiftRender", package: "BmuxSwiftRender"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
