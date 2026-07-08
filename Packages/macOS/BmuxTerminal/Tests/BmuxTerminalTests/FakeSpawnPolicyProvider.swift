@testable import BmuxTerminal

@MainActor
final class FakeSpawnPolicyProvider: TerminalSurfaceSpawnPolicyProviding {
    func currentSpawnPolicy() -> TerminalSurfaceSpawnPolicy {
        TerminalSurfaceSpawnPolicy(
            claudeHooksEnabled: true,
            customClaudePath: nil,
            subagentNotificationEnvironmentKey: "BMUX_TEST_SUPPRESS_SUBAGENT_NOTIFICATIONS",
            suppressSubagentNotifications: false,
            cursorHooksEnabled: true,
            geminiHooksEnabled: true,
            kiroHooksEnabled: true,
            kiroNotificationLevel: "all",
            ampHooksEnabled: true,
            shellIntegrationEnabled: false,
            watchGitStatusEnabled: false,
            showPullRequestsEnabled: false
        )
    }

    func controlSocketPath() -> String {
        "/tmp/bmux-test.sock"
    }
}
