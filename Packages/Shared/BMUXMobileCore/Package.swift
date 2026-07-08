// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BMUXMobileCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BMUXMobileCore",
            targets: ["BMUXMobileCore"]
        ),
    ],
    targets: [
        .target(
            name: "BMUXMobileCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "BMUXMobileCoreTests",
            dependencies: ["BMUXMobileCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
