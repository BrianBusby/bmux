// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ProvenanceEngineCurrentContextSeeder",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../../Packages/macOS/ProvenanceEngine"),
    ],
    targets: [
        .executableTarget(
            name: "ProvenanceEngineCurrentContextSeeder",
            dependencies: [
                .product(name: "ProvenanceEngineContracts", package: "ProvenanceEngine"),
                .product(name: "ProvenanceEngineSDK", package: "ProvenanceEngine"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
