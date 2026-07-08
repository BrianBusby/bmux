// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxWorkspaces",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxWorkspaces",
            targets: ["BmuxWorkspaces"]
        ),
    ],
    dependencies: [
        // WorkspaceGroupNewPlacement (the typed setting value for new
        // in-group workspace placement) is owned by BmuxSettings.
        .package(path: "../BmuxSettings"),
        // Bonsplit drives the Window/ tmux pane-overlay geometry.
        .package(path: "../../../vendor/bonsplit"),
        // BMUXDebugLog backs the Session/ snapshot-restore logging.
        .package(path: "../BMUXDebugLog"),
        // BmuxTestSupport backs FileOpen/ PreferredEditorService UI-test capture.
        .package(path: "../BmuxTestSupport"),
    ],
    targets: [
        .target(
            name: "BmuxWorkspaces",
            dependencies: [
                .product(name: "BmuxSettings", package: "BmuxSettings"),
                .product(name: "Bonsplit", package: "bonsplit"),
                .product(name: "BMUXDebugLog", package: "BMUXDebugLog"),
                .product(name: "BmuxTestSupport", package: "BmuxTestSupport"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxWorkspacesTests",
            dependencies: [
                "BmuxWorkspaces",
                .product(name: "Bonsplit", package: "bonsplit"),
                .product(name: "BmuxTestSupport", package: "BmuxTestSupport"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
