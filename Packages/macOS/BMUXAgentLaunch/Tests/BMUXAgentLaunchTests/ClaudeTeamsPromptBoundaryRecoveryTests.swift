import BMUXAgentLaunch
import Testing

@Suite("Claude Teams prompt boundary isolation")
struct ClaudeTeamsPromptBoundaryRecoveryTests {
    @Test("Drops post-boundary flags for remote-control launches")
    func dropsPostBoundaryFlagsForRemoteControlLaunches() {
        #expect(
            AgentLaunchSanitizer.sanitizedLaunchArguments(
                [
                    "/Applications/bmux.app/Contents/Resources/bin/bmux",
                    "claude-teams",
                    "--remote-control-session-name-prefix",
                    "bmux-team",
                    "--tmux",
                    "please",
                    "--permission-mode",
                    "bypassPermissions",
                ],
                launcher: "claudeTeams",
                fallbackKind: "claude"
            ) == [
                "/Applications/bmux.app/Contents/Resources/bin/bmux",
                "claude-teams",
                "--remote-control-session-name-prefix",
                "bmux-team",
            ]
        )
    }

    @Test("Recovers safe post-boundary flags at end of argv")
    func recoversSafePostBoundaryFlagsAtEndOfArgv() {
        #expect(
            AgentLaunchSanitizer.sanitizedLaunchArguments(
                [
                    "/Applications/bmux.app/Contents/Resources/bin/bmux",
                    "claude-teams",
                    "--remote-control-session-name-prefix",
                    "bmux-team",
                    "--tmux",
                    "side effect should be dropped",
                    "--model",
                    "sonnet",
                    "--permission-mode",
                    "auto",
                ],
                launcher: "claudeTeams",
                fallbackKind: "claude"
            ) == [
                "/Applications/bmux.app/Contents/Resources/bin/bmux",
                "claude-teams",
                "--remote-control-session-name-prefix",
                "bmux-team",
                "--model",
                "sonnet",
                "--permission-mode",
                "auto",
            ]
        )
    }
}
