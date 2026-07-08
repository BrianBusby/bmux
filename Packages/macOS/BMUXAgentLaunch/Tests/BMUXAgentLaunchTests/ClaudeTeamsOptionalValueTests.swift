import BMUXAgentLaunch
import Testing

@Suite("Claude Teams optional values")
struct ClaudeTeamsOptionalValueTests {
    @Test("Preserves split worktree values with spaces before later flags")
    func preservesSplitWorktreeValuesWithSpacesBeforeLaterFlags() {
        #expect(
            AgentLaunchSanitizer.sanitizedLaunchArguments(
                [
                    "/Applications/bmux.app/Contents/Resources/bin/bmux",
                    "claude-teams",
                    "--worktree",
                    "/tmp/team repo",
                    "--model",
                    "sonnet",
                ],
                launcher: "claudeTeams",
                fallbackKind: "claude"
            ) == [
                "/Applications/bmux.app/Contents/Resources/bin/bmux",
                "claude-teams",
                "--worktree",
                "/tmp/team repo",
                "--model",
                "sonnet",
            ]
        )
    }

    @Test("Does not consume multi-word prompt as worktree value")
    func doesNotConsumeMultiWordPromptAsWorktreeValue() {
        #expect(
            AgentLaunchSanitizer.sanitizedLaunchArguments(
                [
                    "/Applications/bmux.app/Contents/Resources/bin/bmux",
                    "claude-teams",
                    "--worktree",
                    "fix the bug",
                    "--model",
                    "sonnet",
                ],
                launcher: "claudeTeams",
                fallbackKind: "claude"
            ) == [
                "/Applications/bmux.app/Contents/Resources/bin/bmux",
                "claude-teams",
                "--worktree",
            ]
        )
    }

    @Test("Does not consume multi-word prompt as remote-control value")
    func doesNotConsumeMultiWordPromptAsRemoteControlValue() {
        #expect(
            AgentLaunchSanitizer.sanitizedLaunchArguments(
                [
                    "/Applications/bmux.app/Contents/Resources/bin/bmux",
                    "claude-teams",
                    "--remote-control",
                    "fix the bug",
                    "--model",
                    "sonnet",
                ],
                launcher: "claudeTeams",
                fallbackKind: "claude"
            ) == [
                "/Applications/bmux.app/Contents/Resources/bin/bmux",
                "claude-teams",
                "--remote-control",
            ]
        )
    }
}
