// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BMUXProjectModel",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BMUXProjectModel",
            targets: ["BMUXProjectModel"]
        ),
        .executable(
            name: "bmux-project-dump",
            targets: ["BMUXProjectDump"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/tuist/XcodeProj.git",
            from: "9.0.0"
        ),
    ],
    targets: [
        .target(
            name: "BMUXProjectModel",
            dependencies: [
                .product(name: "XcodeProj", package: "XcodeProj"),
            ]
        ),
        .executableTarget(
            name: "BMUXProjectDump",
            dependencies: ["BMUXProjectModel"]
        ),
        .testTarget(
            name: "BMUXProjectModelTests",
            dependencies: ["BMUXProjectModel"]
        ),
    ]
)
