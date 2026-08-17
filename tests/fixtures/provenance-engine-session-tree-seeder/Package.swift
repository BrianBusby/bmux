// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ProvenanceEngineSessionTreeSeeder",
    platforms: [
        .macOS(.v10_15),
    ],
    dependencies: [
        .package(path: "../../../Packages/macOS/ProvenanceEngine"),
    ],
    targets: [
        .executableTarget(
            name: "ProvenanceEngineSessionTreeSeeder",
            dependencies: [
                .product(name: "ProvenanceEngineContracts", package: "ProvenanceEngine"),
                .product(name: "ProvenanceEngineSDK", package: "ProvenanceEngine"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
