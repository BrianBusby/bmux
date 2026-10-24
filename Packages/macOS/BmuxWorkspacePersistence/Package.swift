// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxWorkspacePersistence",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BmuxWorkspacePersistence", targets: ["BmuxWorkspacePersistence"]),
    ],
    targets: [
        .target(
            name: "BmuxWorkspacePersistence",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxWorkspacePersistenceTests",
            dependencies: ["BmuxWorkspacePersistence"]
        ),
    ]
)
