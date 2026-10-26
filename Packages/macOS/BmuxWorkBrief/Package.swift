// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BmuxWorkBrief",
    platforms: [.macOS(.v14)],
    products: [.library(name: "BmuxWorkBrief", targets: ["BmuxWorkBrief"])],
    targets: [
        .target(name: "BmuxWorkBrief", swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "BmuxWorkBriefTests", dependencies: ["BmuxWorkBrief"]),
    ]
)
