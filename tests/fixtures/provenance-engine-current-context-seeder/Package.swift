// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ProvenanceEngineCurrentContextSeeder",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "git@github.com:BrianBusby/provenance-engine.git", revision: "7ed4450410f344f01472ba62f534a04c6c0d2774"),
    ],
    targets: [
        .executableTarget(
            name: "ProvenanceEngineCurrentContextSeeder",
            dependencies: [
                .product(name: "ProvenanceEngineContracts", package: "provenance-engine"),
                .product(name: "ProvenanceEngineSDK", package: "provenance-engine"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
