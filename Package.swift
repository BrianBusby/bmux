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
        .target(
            name: "ProvenanceEngineSQLite",
            dependencies: ["ProvenanceEngineContracts"],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .testTarget(
            name: "ProvenanceEngineContractsTests",
            dependencies: ["ProvenanceEngineContracts"]
        ),
        .testTarget(
            name: "ProvenanceEngineSQLiteTests",
            dependencies: ["ProvenanceEngineSQLite"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
