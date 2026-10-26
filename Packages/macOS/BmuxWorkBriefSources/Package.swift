// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BmuxWorkBriefSources",
    platforms: [.macOS(.v14)],
    products: [.library(name: "BmuxWorkBriefSources", targets: ["BmuxWorkBriefSources"])],
    dependencies: [.package(path: "../BmuxWorkBrief")],
    targets: [
        .target(name: "BmuxWorkBriefSources", dependencies: ["BmuxWorkBrief"],
                swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "BmuxWorkBriefSourcesTests", dependencies: ["BmuxWorkBriefSources"]),
    ]
)
