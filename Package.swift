// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ProvenanceEngine",
    products: [
        .library(
            name: "ProvenanceEngineContracts",
            targets: ["ProvenanceEngineContracts"]
        ),
    ],
    targets: [
        .target(name: "ProvenanceEngineContracts"),
        .testTarget(
            name: "ProvenanceEngineContractsTests",
            dependencies: ["ProvenanceEngineContracts"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
