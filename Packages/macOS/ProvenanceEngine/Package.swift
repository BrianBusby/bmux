// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ProvenanceEngine",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "ProvenanceEngineContracts",
            targets: ["ProvenanceEngineContracts"]
        ),
        .library(
            name: "ProvenanceEngineSDK",
            targets: ["ProvenanceEngineSDK"]
        ),
        .executable(
            name: "ProvenanceRetrievalDemoSeed",
            targets: ["ProvenanceRetrievalDemoSeed"]
        ),
    ],
    targets: [
        .target(name: "ProvenanceEngineContracts"),
        .target(
            name: "ProvenanceEngineSDK",
            dependencies: [
                "ProvenanceEngineContracts",
                "ProvenanceEngineSQLite",
            ]
        ),
        .target(
            name: "ProvenanceEngineSQLite",
            dependencies: ["ProvenanceEngineContracts"],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .executableTarget(
            name: "ProvenanceRetrievalDemoSeed",
            dependencies: [
                "ProvenanceEngineContracts",
                "ProvenanceEngineSDK",
            ],
            path: "Examples/ProvenanceRetrievalDemoSeed"
        ),
        .testTarget(
            name: "ProvenanceEngineContractsTests",
            dependencies: ["ProvenanceEngineContracts"]
        ),
        .testTarget(
            name: "ProvenanceEngineSQLiteTests",
            dependencies: ["ProvenanceEngineSQLite"]
        ),
        .testTarget(
            name: "ProvenanceEngineSDKTests",
            dependencies: [
                "ProvenanceEngineContracts",
                "ProvenanceEngineSDK",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
