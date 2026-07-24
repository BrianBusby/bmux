// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ProvenanceEngineFileExplanationSeeder",
    platforms: [
        .macOS(.v10_15),
    ],
    dependencies: [
        .package(
            url: "git@github.com:BrianBusby/provenance-engine.git",
            revision: "384026e36087dda576e25343907c3e06d8a4d594"
        ),
    ],
    targets: [
        .executableTarget(
            name: "ProvenanceEngineFileExplanationSeeder",
            dependencies: [
                .product(name: "ProvenanceEngineContracts", package: "provenance-engine"),
                .product(name: "ProvenanceEngineSDK", package: "provenance-engine"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
