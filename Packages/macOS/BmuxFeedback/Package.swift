// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxFeedback",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxFeedback",
            targets: ["BmuxFeedback"]
        ),
    ],
    dependencies: [
        .package(path: "../BmuxFoundation"),
    ],
    targets: [
        .target(
            name: "BmuxFeedback",
            dependencies: [
                "BmuxFoundation",
            ],
            resources: [
                // Folded from BmuxFeedbackUI: the composer's localized strings.
                .process("ComposerUI/Resources"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxFeedbackTests",
            dependencies: ["BmuxFeedback"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
