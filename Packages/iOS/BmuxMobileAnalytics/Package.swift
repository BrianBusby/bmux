// swift-tools-version: 6.0

import PackageDescription

// `BmuxMobileAnalytics` is the concrete analytics infrastructure: the
// fire-and-forget `AnalyticsEmitter` actor, the pure sessionization and
// connection-edge throttle logic, and the HTTP capture client that posts batches
// to the bmux web analytics proxy. It conforms to the `AnalyticsEmitting` seam
// declared in `BMUXMobileCore`, so it depends only on that base package and
// Foundation — keeping the package graph an acyclic DAG. Everything it touches
// (the opt-out gate, the clock, `UserDefaults`, reachability, the base URL) is
// injected at construction so the actor is testable without the app.
let package = Package(
    name: "BmuxMobileAnalytics",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BmuxMobileAnalytics",
            targets: ["BmuxMobileAnalytics"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/BMUXMobileCore"),
    ],
    targets: [
        .target(
            name: "BmuxMobileAnalytics",
            dependencies: [
                "BMUXMobileCore",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "BmuxMobileAnalyticsTests",
            dependencies: ["BmuxMobileAnalytics"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
