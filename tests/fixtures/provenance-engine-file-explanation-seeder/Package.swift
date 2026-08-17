// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ProvenanceEngineFileExplanationSeeder",
    platforms: [
        .macOS(.v10_15),
    ],
    dependencies: [
        .package(path: "../../../Packages/macOS/ProvenanceEngine"),
    ],
    targets: [
        .executableTarget(
            name: "ProvenanceEngineFileExplanationSeeder",
            dependencies: [
                .product(name: "ProvenanceEngineContracts", package: "ProvenanceEngine"),
                .product(name: "ProvenanceEngineSDK", package: "ProvenanceEngine"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
