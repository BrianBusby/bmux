import BMUXAgentLaunch
import Testing

@Suite("KimiCodeHookConfig")
struct KimiCodeHookConfigTests {
    @Test("Installs hooks into empty config")
    func installsHooksIntoEmptyConfig() {
        let events = [
            KimiCodeHookConfig.Event(
                name: "SessionStart",
                command: "bmux hooks kimi session-start",
                timeout: 10
            ),
            KimiCodeHookConfig.Event(
                name: "PreToolUse",
                command: "bmux hooks feed --source kimi --event PreToolUse",
                timeout: 120
            ),
        ]

        let installed = KimiCodeHookConfig.installing(events: events, in: "")

        #expect(installed == """
        # bmux-kimi-hooks-7c3a9f12-4e8b-4d2a-9f15-6b8c0d1e2a3f begin
        [[hooks]]
        event = "SessionStart"
        command = "bmux hooks kimi session-start"
        timeout = 10

        [[hooks]]
        event = "PreToolUse"
        command = "bmux hooks feed --source kimi --event PreToolUse"
        timeout = 120

        # bmux-kimi-hooks-7c3a9f12-4e8b-4d2a-9f15-6b8c0d1e2a3f end

        """)
    }

    @Test("Install preserves existing user content with separating blank line")
    func installPreservesExistingUserContentWithSeparatingBlankLine() {
        let existing = """
        model = "kimi-k2"
        telemetry = false

        """
        let events = [
            KimiCodeHookConfig.Event(name: "Stop", command: "bmux hooks kimi stop", timeout: 10),
        ]

        let installed = KimiCodeHookConfig.installing(events: events, in: existing)

        #expect(installed == """
        model = "kimi-k2"
        telemetry = false

        # bmux-kimi-hooks-7c3a9f12-4e8b-4d2a-9f15-6b8c0d1e2a3f begin
        [[hooks]]
        event = "Stop"
        command = "bmux hooks kimi stop"
        timeout = 10

        # bmux-kimi-hooks-7c3a9f12-4e8b-4d2a-9f15-6b8c0d1e2a3f end

        """)
    }

    @Test("Install is idempotent")
    func installIsIdempotent() {
        let existing = "model = \"kimi-k2\"\n"
        let events = [
            KimiCodeHookConfig.Event(name: "Stop", command: "bmux hooks kimi stop", timeout: 10),
        ]

        let installed = KimiCodeHookConfig.installing(events: events, in: existing)

        #expect(KimiCodeHookConfig.installing(events: events, in: installed) == installed)
    }

    @Test("Reinstall replaces stale bmux block")
    func reinstallReplacesStaleBmuxBlock() {
        let stale = KimiCodeHookConfig.installing(
            events: [KimiCodeHookConfig.Event(name: "Stop", command: "bmux hooks kimi stop", timeout: 10)],
            in: "model = \"kimi-k2\"\n"
        )

        let reinstalled = KimiCodeHookConfig.installing(
            events: [KimiCodeHookConfig.Event(name: "Stop", command: "bmux hooks kimi stop", timeout: 20)],
            in: stale
        )

        #expect(reinstalled.components(separatedBy: "# bmux-kimi-hooks-7c3a9f12-4e8b-4d2a-9f15-6b8c0d1e2a3f begin").count == 2)
        #expect(reinstalled.contains("timeout = 20"))
        #expect(!reinstalled.contains("timeout = 10"))
    }

    @Test("Install uninstall round trip restores normalized existing content")
    func installUninstallRoundTripRestoresNormalizedExistingContent() {
        let existing = "model = \"kimi-k2\"\ntelemetry = false\n\n"
        let events = [
            KimiCodeHookConfig.Event(name: "Stop", command: "bmux hooks kimi stop", timeout: 10),
        ]

        let installed = KimiCodeHookConfig.installing(events: events, in: existing)

        #expect(KimiCodeHookConfig.uninstalling(from: installed) == existing)
    }

    @Test("Uninstall without bmux block leaves content unchanged")
    func uninstallWithoutBmuxBlockLeavesContentUnchanged() {
        let existing = """
        model = "kimi-k2"
        telemetry = false

        """

        #expect(KimiCodeHookConfig.uninstalling(from: existing) == existing)
    }

    @Test("Uninstall removes orphaned begin marker without dropping following TOML")
    func uninstallRemovesOrphanedBeginMarkerWithoutDroppingFollowingTOML() {
        let existing = """
        model = "kimi-k2"
        # bmux-kimi-hooks-7c3a9f12-4e8b-4d2a-9f15-6b8c0d1e2a3f begin
        telemetry = false

        """

        #expect(KimiCodeHookConfig.uninstalling(from: existing) == """
        model = "kimi-k2"
        telemetry = false

        """)
    }

    @Test("Uninstall removes consecutive orphaned begin markers without dropping following TOML")
    func uninstallRemovesConsecutiveOrphanedBeginMarkersWithoutDroppingFollowingTOML() {
        let existing = """
        # bmux-kimi-hooks-7c3a9f12-4e8b-4d2a-9f15-6b8c0d1e2a3f begin
        # bmux-kimi-hooks-7c3a9f12-4e8b-4d2a-9f15-6b8c0d1e2a3f begin
        model = "kimi-k2"

        """

        #expect(KimiCodeHookConfig.uninstalling(from: existing) == """
        model = "kimi-k2"

        """)
    }

    @Test("Escapes TOML basic string content")
    func escapesTOMLBasicStringContent() {
        let events = [
            KimiCodeHookConfig.Event(
                name: "PermissionRequest",
                command: "bmux hooks \"kimi\" \\\tpermission",
                timeout: 10
            ),
        ]

        let installed = KimiCodeHookConfig.installing(events: events, in: "")

        #expect(installed.contains(#"command = "bmux hooks \"kimi\" \\\tpermission""#))
    }
}
