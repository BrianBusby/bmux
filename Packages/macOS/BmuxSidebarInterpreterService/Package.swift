// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BmuxSidebarInterpreterService",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        // Host-side client + wire protocol the app links against.
        .library(
            name: "BmuxSidebarInterpreterClient",
            targets: ["BmuxSidebarInterpreterClient"]
        ),
        // The out-of-process worker that runs the untrusted interpreter.
        .executable(
            name: "bmux-sidebar-interpreter",
            targets: ["bmux-sidebar-interpreter"]
        ),
        // Headless protocol fixture for RenderWorkerClient supervision tests.
        .executable(
            name: "bmux-sidebar-render-fixture",
            targets: ["bmux-sidebar-render-fixture"]
        ),
        // Remote rendering: the faceless render-worker loop and the host-side
        // layer-hosting sidebar surface.
        .library(
            name: "BmuxSidebarRemoteRender",
            targets: ["BmuxSidebarRemoteRender"]
        ),
    ],
    dependencies: [
        .package(path: "../BmuxSwiftRender"),
        .package(path: "../BmuxSwiftRenderUI"),
    ],
    targets: [
        .target(
            name: "BmuxSidebarInterpreterClient",
            dependencies: ["BmuxSwiftRender"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .executableTarget(
            name: "bmux-sidebar-interpreter",
            dependencies: ["BmuxSidebarInterpreterClient"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .executableTarget(
            name: "bmux-sidebar-render-fixture",
            dependencies: ["BmuxSidebarInterpreterClient"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "BmuxSidebarRemoteRender",
            dependencies: [
                "BmuxSidebarInterpreterClient",
                .product(name: "BmuxSwiftRenderUI", package: "BmuxSwiftRenderUI"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "BmuxSidebarInterpreterClientTests",
            dependencies: ["BmuxSidebarInterpreterClient"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "BmuxSidebarRemoteRenderTests",
            dependencies: ["BmuxSidebarRemoteRender"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
