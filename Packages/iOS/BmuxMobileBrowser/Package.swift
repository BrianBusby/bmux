// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxMobileBrowser",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxMobileBrowser",
            targets: ["BmuxMobileBrowser"]
        ),
    ],
    dependencies: [
        // Localized-string helpers (`L10n`). `BmuxMobileSupport` is a leaf with
        // no dependencies, so the browser package stays low in the DAG.
        .package(path: "../BmuxMobileSupport"),
    ],
    targets: [
        // A self-contained, phone-local browser surface. P1 browser state never
        // touches the Mac, so this package sits low in the DAG: it depends only
        // on the leaf `BmuxMobileSupport` and links Foundation/WebKit/SwiftUI.
        .target(
            name: "BmuxMobileBrowser",
            dependencies: [
                "BmuxMobileSupport",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxMobileBrowserTests",
            dependencies: ["BmuxMobileBrowser"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
