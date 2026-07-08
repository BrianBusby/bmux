import Testing

import BmuxSettings

@Suite struct SocketControlSettingsTests {
    @Test func migrateModeMapsLegacyAndUnknownValues() {
        #expect(SocketControlSettings.migrateMode("off") == .off)
        #expect(SocketControlSettings.migrateMode("bmux_only") == .bmuxOnly)
        #expect(SocketControlSettings.migrateMode("ALLOW-ALL") == .allowAll)
        // Legacy aliases.
        #expect(SocketControlSettings.migrateMode("notifications") == .automation)
        #expect(SocketControlSettings.migrateMode("full") == .allowAll)
        // Unknown falls back to the default.
        #expect(SocketControlSettings.migrateMode("bogus") == .bmuxOnly)
    }

    @Test func effectiveModeHonorsEnableOverride() {
        #expect(
            SocketControlSettings.effectiveMode(
                userMode: .password,
                environment: ["BMUX_SOCKET_ENABLE": "0"]
            ) == .off
        )
        #expect(
            SocketControlSettings.effectiveMode(
                userMode: .off,
                environment: ["BMUX_SOCKET_ENABLE": "1"]
            ) == .bmuxOnly
        )
    }

    @Test func effectiveModeHonorsModeOverride() {
        #expect(
            SocketControlSettings.effectiveMode(
                userMode: .bmuxOnly,
                environment: ["BMUX_SOCKET_MODE": "allowall"]
            ) == .allowAll
        )
    }

    @Test func effectiveModeFallsBackToUserMode() {
        #expect(
            SocketControlSettings.effectiveMode(userMode: .automation, environment: [:]) == .automation
        )
    }

    @Test func truthyParsing() {
        for value in ["1", "true", "YES", "on"] {
            #expect(SocketControlSettings.isTruthy(value))
        }
        for value in ["0", "false", "", "nope"] {
            #expect(!SocketControlSettings.isTruthy(value))
        }
    }

    @Test func taggedDevBuildDetection() {
        #expect(SocketControlSettings.isTaggedDevBuild(bundleIdentifier: "com.bmuxterm.app.debug.my-tag"))
        #expect(!SocketControlSettings.isTaggedDevBuild(bundleIdentifier: "com.bmuxterm.app.debug"))
        #expect(!SocketControlSettings.isTaggedDevBuild(bundleIdentifier: "com.bmuxterm.app"))
    }

    @Test func untaggedDebugLaunchIsBlockedOnlyForBareDebugBundle() {
        // Bare debug bundle, no tag, not under test => blocked.
        #expect(
            SocketControlSettings.shouldBlockUntaggedDebugLaunch(
                environment: [:],
                bundleIdentifier: "com.bmuxterm.app.debug",
                isDebugBuild: true
            )
        )
        // XCUITest launches the app as a separate process without XCTest env vars,
        // so any BMUX_UI_TEST_ marker must bypass blocking for a bare debug bundle.
        #expect(
            !SocketControlSettings.shouldBlockUntaggedDebugLaunch(
                environment: ["BMUX_UI_TEST_RUN": "1"],
                bundleIdentifier: "com.bmuxterm.app.debug",
                isDebugBuild: true
            )
        )
        // Tagged debug bundle => allowed.
        #expect(
            !SocketControlSettings.shouldBlockUntaggedDebugLaunch(
                environment: [:],
                bundleIdentifier: "com.bmuxterm.app.debug.tag",
                isDebugBuild: true
            )
        )
        // Release build => never blocked.
        #expect(
            !SocketControlSettings.shouldBlockUntaggedDebugLaunch(
                environment: [:],
                bundleIdentifier: "com.bmuxterm.app",
                isDebugBuild: false
            )
        )
    }

    @Test func socketPathHonorsOverrideForTaggedDevWhenAllowed() {
        let path = SocketControlSettings.socketPath(
            environment: [
                "BMUX_SOCKET_PATH": "/tmp/bmux-custom.sock",
                "BMUX_ALLOW_SOCKET_OVERRIDE": "1",
            ],
            bundleIdentifier: "com.bmuxterm.app.debug.tag",
            isDebugBuild: true,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .missing }
        )
        #expect(path == "/tmp/bmux-custom.sock")
    }

    @Test func bareDebugXCTestLaunchUsesScopedSocketFallback() {
        let environment = [
            "XCTestConfigurationFilePath": "/tmp/Test-bmux-unit-2026.06.17.xctestconfiguration",
        ]
        let path = SocketControlSettings.socketPath(
            environment: environment,
            bundleIdentifier: "com.bmuxterm.app.debug",
            isDebugBuild: true,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .missing }
        )
        let defaultPath = SocketControlSettings.defaultSocketPath(
            bundleIdentifier: "com.bmuxterm.app.debug",
            environment: environment,
            isDebugBuild: true,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .missing }
        )
        #expect(path.hasPrefix("/tmp/bmux-xctest-"))
        #expect(path.hasSuffix(".sock"))
        #expect(path != "/tmp/bmux-debug.sock")
        #expect(path == defaultPath)
    }

    @Test func explicitSocketOverrideStillWinsUnderXCTest() {
        let path = SocketControlSettings.socketPath(
            environment: [
                "BMUX_SOCKET_PATH": "/tmp/bmux-forced.sock",
                "XCTestConfigurationFilePath": "/tmp/Test-bmux-unit-2026.06.17.xctestconfiguration",
            ],
            bundleIdentifier: "com.bmuxterm.app.debug",
            isDebugBuild: true,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .missing }
        )
        #expect(path == "/tmp/bmux-forced.sock")
    }

    @Test func dyldOnlyXCTestLaunchUsesScopedSocketFallback() {
        let path = SocketControlSettings.socketPath(
            environment: [
                "DYLD_INSERT_LIBRARIES": "/Applications/Xcode.app/Contents/Developer/usr/lib/libXCTestSwiftSupport.dylib",
            ],
            bundleIdentifier: "com.bmuxterm.app.debug",
            isDebugBuild: true,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .missing }
        )
        #expect(path.hasPrefix("/tmp/bmux-xctest-"))
        #expect(path.hasSuffix(".sock"))
        #expect(path != "/tmp/bmux-debug.sock")
    }

    @Test func xctestSocketFallbackHashesFullPath() {
        let first = SocketControlSettings.socketPath(
            environment: [
                "XCTestConfigurationFilePath": "/tmp/first/Test-bmux-unit.xctestconfiguration",
            ],
            bundleIdentifier: "com.bmuxterm.app.debug",
            isDebugBuild: true,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .missing }
        )
        let second = SocketControlSettings.socketPath(
            environment: [
                "XCTestConfigurationFilePath": "/tmp/second/Test-bmux-unit.xctestconfiguration",
            ],
            bundleIdentifier: "com.bmuxterm.app.debug",
            isDebugBuild: true,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .missing }
        )
        #expect(first.hasPrefix("/tmp/bmux-xctest-"))
        #expect(second.hasPrefix("/tmp/bmux-xctest-"))
        #expect(first != second)
    }

    @Test func taggedDebugXCTestLaunchStillUsesTaggedSocket() {
        let path = SocketControlSettings.socketPath(
            environment: [
                "BMUX_TAG": "ci-split-theme",
                "XCTestConfigurationFilePath": "/tmp/Test-bmux-unit-2026.06.17.xctestconfiguration",
            ],
            bundleIdentifier: "com.bmuxterm.app.debug",
            isDebugBuild: true,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .missing }
        )
        #expect(path == "/tmp/bmux-debug-ci-split-theme.sock")
    }
}
