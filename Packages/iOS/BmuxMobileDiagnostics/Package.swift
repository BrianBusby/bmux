// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxMobileDiagnostics",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxMobileDiagnostics",
            targets: ["BmuxMobileDiagnostics"]
        ),
    ],
    targets: [
        .target(
            name: "BmuxMobileDiagnostics",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxMobileDiagnosticsTests",
            dependencies: ["BmuxMobileDiagnostics"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
