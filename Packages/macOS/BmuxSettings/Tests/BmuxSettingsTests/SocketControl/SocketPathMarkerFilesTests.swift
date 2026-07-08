import Testing
@testable import BmuxSettings

@Test func markerFilesAreVariantAware() {
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "com.bmuxterm.app",
        environment: [:]
    ) == .stable)
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "com.bmuxterm.app.nightly",
        environment: [:]
    ) == .nightly(slug: nil))
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "com.bmuxterm.app.debug.agent",
        environment: [:]
    ) == .dev(slug: "agent"))
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "com.bmuxterm.app.debug",
        environment: ["BMUX_TAG": "Issue 3542"]
    ) == .dev(slug: "issue-3542"))
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "com.bmuxterm.app.debug",
        environment: ["BMUX_TAG": "café"]
    ) == .dev(slug: "caf"))
}

@Test func defaultSocketPathsStayVariantScoped() {
    #expect(SocketPathMarkerFiles.defaultSocketPath(
        bundleIdentifier: "com.bmuxterm.app",
        environment: [:],
        isDebugBuild: false,
        stableSocketPath: "/stable/bmux.sock"
    ) == "/stable/bmux.sock")
    #expect(SocketPathMarkerFiles.defaultSocketPath(
        bundleIdentifier: "com.bmuxterm.app.nightly",
        environment: [:],
        isDebugBuild: false,
        stableSocketPath: "/stable/bmux.sock"
    ) == "/tmp/bmux-nightly.sock")
    #expect(SocketPathMarkerFiles.defaultSocketPath(
        bundleIdentifier: "com.bmuxterm.app.staging.my-feature",
        environment: [:],
        isDebugBuild: false,
        stableSocketPath: "/stable/bmux.sock"
    ) == "/tmp/bmux-staging-my-feature.sock")
    #expect(SocketPathMarkerFiles.defaultSocketPath(
        bundleIdentifier: "com.bmuxterm.app.debug",
        environment: ["BMUX_TAG": "Issue 3542"],
        isDebugBuild: false,
        stableSocketPath: "/stable/bmux.sock"
    ) == "/tmp/bmux-debug-issue-3542.sock")
}
