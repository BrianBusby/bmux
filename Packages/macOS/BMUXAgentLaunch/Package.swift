// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BMUXAgentLaunch",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BMUXAgentLaunch",
            targets: ["BMUXAgentLaunch"]
        ),
    ],
    targets: [
        .target(
            name: "BMUXAgentLaunch"
        ),
        .testTarget(
            name: "BMUXAgentLaunchTests",
            dependencies: ["BMUXAgentLaunch"]
        ),
    ]
)
