// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxContextEfficiency",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxContextEfficiency",
            targets: ["BmuxContextEfficiency"]
        ),
    ],
    targets: [
        .target(
            name: "BmuxContextEfficiency",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .testTarget(
            name: "BmuxContextEfficiencyTests",
            dependencies: ["BmuxContextEfficiency"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
