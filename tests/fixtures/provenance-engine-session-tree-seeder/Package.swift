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
            revision: "2026914454a00ccc6c45d686ea741111b0a01229"
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
