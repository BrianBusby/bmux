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
            revision: "126afde36671f53a137953200e7883e6b4093ac3"
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
