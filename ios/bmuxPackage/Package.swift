// swift-tools-version: 6.0

import PackageDescription

// `bmuxFeature` is the iOS composition-root package, not a catch-all. After the
// 5079 refactor it holds only the runtime DI bundle (`BMUXMobileRuntime`), the
// auth composition (`MobileAuthComposition` over `BmuxAuthRuntime`), and the
// root scene (`BMUXMobileRootScene`). The store, RPC, persistence, terminal,
// and view code were lifted into the focused packages it depends on below. See
// README.md for the per-type role table.
let package = Package(
    name: "bmuxFeature",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "bmuxFeature",
            targets: ["bmuxFeature"]
        ),
    ],
    dependencies: [
        .package(path: "../../Packages/Shared/BMUXAuthCore"),
        .package(path: "../../Packages/Shared/BmuxAuthRuntime"),
        .package(path: "../../Packages/Shared/BmuxClientConfig"),
        .package(path: "../../Packages/Shared/BMUXMobileCore"),
        .package(path: "../../Packages/iOS/BmuxMobileAnalytics"),
        .package(path: "../../Packages/iOS/BmuxMobileBrowser"),
        .package(path: "../../Packages/iOS/BmuxMobileCamera"),
        .package(path: "../../Packages/iOS/BmuxMobileDiagnostics"),
        .package(path: "../../Packages/iOS/BmuxMobilePairedMac"),
        .package(path: "../../Packages/iOS/BmuxMobileRPC"),
        .package(path: "../../Packages/iOS/BmuxMobileShell"),
        .package(path: "../../Packages/iOS/BmuxMobileShellModel"),
        .package(path: "../../Packages/iOS/BmuxMobileShellUI"),
        .package(path: "../../Packages/iOS/BmuxMobileSupport"),
        .package(path: "../../Packages/iOS/BmuxMobileTerminal"),
        .package(path: "../../Packages/iOS/BmuxMobileTerminalKit"),
        .package(path: "../../Packages/iOS/BmuxMobileTransport"),
        .package(path: "../../Packages/iOS/BmuxMobileWorkspace"),
        .package(path: "../../vendor/stack-auth-swift-sdk-prerelease"),
    ],
    targets: [
        .target(
            name: "bmuxFeature",
            dependencies: [
                "BMUXAuthCore",
                "BmuxAuthRuntime",
                "BmuxClientConfig",
                "BMUXMobileCore",
                "BmuxMobileAnalytics",
                "BmuxMobileBrowser",
                "BmuxMobileCamera",
                "BmuxMobileDiagnostics",
                "BmuxMobilePairedMac",
                "BmuxMobileRPC",
                "BmuxMobileShell",
                "BmuxMobileShellModel",
                "BmuxMobileShellUI",
                "BmuxMobileSupport",
                "BmuxMobileTerminal",
                "BmuxMobileTerminalKit",
                "BmuxMobileTransport",
                "BmuxMobileWorkspace",
                .product(name: "StackAuth", package: "stack-auth-swift-sdk-prerelease"),
            ],
            swiftSettings: [
                .define("BMUX_DEV_AUTH", .when(configuration: .debug)),
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "bmuxFeatureTests",
            dependencies: [
                "bmuxFeature",
                "BMUXAuthCore",
                "BmuxAuthRuntime",
                "BmuxClientConfig",
                "BMUXMobileCore",
                "BmuxMobileAnalytics",
                "BmuxMobileBrowser",
                "BmuxMobileCamera",
                "BmuxMobileDiagnostics",
                "BmuxMobilePairedMac",
                "BmuxMobileRPC",
                "BmuxMobileShell",
                "BmuxMobileShellModel",
                "BmuxMobileShellUI",
                "BmuxMobileSupport",
                "BmuxMobileTerminal",
                "BmuxMobileTerminalKit",
                "BmuxMobileTransport",
                "BmuxMobileWorkspace",
                .product(name: "StackAuth", package: "stack-auth-swift-sdk-prerelease"),
            ],
            swiftSettings: [
                .define("BMUX_DEV_AUTH", .when(configuration: .debug)),
            ]
        ),
    ]
)
