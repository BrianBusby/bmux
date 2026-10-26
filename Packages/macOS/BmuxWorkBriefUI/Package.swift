// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BmuxWorkBriefUI",
    platforms: [.macOS(.v14)],
    products: [.library(name: "BmuxWorkBriefUI", targets: ["BmuxWorkBriefUI"])],
    dependencies: [.package(path: "../BmuxWorkBrief")],
    targets: [.target(name: "BmuxWorkBriefUI", dependencies: ["BmuxWorkBrief"],
        swiftSettings: [.swiftLanguageMode(.v6)])]
)
