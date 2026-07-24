// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ProvenanceEngineSessionTreeSeeder",
    platforms: [
        .macOS(.v10_15),
    ],
    dependencies: [
        .package(
            url: "git@github.com:BrianBusby/provenance-engine.git",
            revision: "dbdc4b7e8b33bc0dc9c160d0f23501d2062e213e"
        ),
    ],
    targets: [
        .executableTarget(
            name: "ProvenanceEngineSessionTreeSeeder",
            dependencies: [
                .product(name: "ProvenanceEngineContracts", package: "provenance-engine"),
                .product(name: "ProvenanceEngineSDK", package: "provenance-engine"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
