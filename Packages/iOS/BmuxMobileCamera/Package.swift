// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxMobileCamera",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxMobileCamera",
            targets: ["BmuxMobileCamera"]
        ),
    ],
    targets: [
        .target(
            name: "BmuxMobileCamera",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxMobileCameraTests",
            dependencies: ["BmuxMobileCamera"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
