import BMUXAgentLaunch
import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

struct AgentForkCommandContractTests {
    @Test
    func forkCommandsUseVerifiedAgentForkSyntaxAndPreserveContext() {
        let claude = SessionRestorableAgentSnapshot(
            kind: .claude,
            sessionId: "24ec0052-450c-4914-b1dd-2ee80d4bc84b",
            workingDirectory: "/Users/lawrence/fun",
            launchCommand: AgentLaunchCommandSnapshot(
                launcher: "claude",
                executablePath: "/Users/lawrence/.local/bin/claude",
                arguments: [
                    "/Users/lawrence/.local/bin/claude",
                    "--dangerously-load-development-channels",
                    "server:custom-dev-channel",
                    "--dangerously-skip-permissions"
                ],
                workingDirectory: "/Users/lawrence/fun",
                environment: [
                    "CLAUDE_CONFIG_DIR": "/Users/lawrence/.codex-accounts/claude/_p1775010019397",
                    "PATH": "/Users/lawrence/.local/bin:/usr/bin",
                    "SHELL": "/bin/zsh"
                ],
                capturedAt: 123,
                source: "environment"
            )
        )
        let claudeFork = SessionRestorableAgentSnapshot(
            kind: .claude,
            sessionId: "claude-fork-child",
            workingDirectory: "/Users/lawrence/fun",
            launchCommand: AgentLaunchCommandSnapshot(
                launcher: "claude",
                executablePath: "/Users/lawrence/.local/bin/claude",
                arguments: [
                    "/Users/lawrence/.local/bin/claude",
                    "--resume",
                    "24ec0052-450c-4914-b1dd-2ee80d4bc84b",
                    "--fork-session",
                    "--model",
                    "sonnet",
                    "--dangerously-skip-permissions"
                ],
                workingDirectory: "/Users/lawrence/fun",
                environment: [
                    "CLAUDE_CONFIG_DIR": "/Users/lawrence/.codex-accounts/claude/_p1775010019397"
                ],
                capturedAt: 123,
                source: "environment"
            )
        )
        let codex = SessionRestorableAgentSnapshot(
            kind: .codex,
            sessionId: "019dad34-d218-7943-b81a-eddac5c87951",
            workingDirectory: "/Users/example/repo",
            launchCommand: AgentLaunchCommandSnapshot(
                launcher: "codex",
                executablePath: "/Users/example/.bun/bin/codex",
                arguments: [
                    "/Users/example/.bun/bin/codex",
                    "--model",
                    "gpt-5.4",
                    "--sandbox",
                    "danger-full-access",
                    "--ask-for-approval",
                    "never",
                    "--search",
                    "--cd",
                    "/Users/example/repo",
                    "initial prompt should not replay"
                ],
                workingDirectory: "/Users/example/repo",
                environment: ["CODEX_HOME": "/tmp/codex home"],
                capturedAt: 123,
                source: "process"
            )
        )
        let codexWithImage = SessionRestorableAgentSnapshot(
            kind: .codex,
            sessionId: "019image-session",
            workingDirectory: "/Users/example/repo",
            launchCommand: AgentLaunchCommandSnapshot(
                launcher: "codex",
                executablePath: "/Users/example/.bun/bin/codex",
                arguments: [
                    "/Users/example/.bun/bin/codex",
                    "--image",
                    "/tmp/screenshot.png",
                    "--model",
                    "gpt-5.4",
                    "initial prompt should not replay"
                ],
                workingDirectory: "/Users/example/repo",
                environment: ["CODEX_HOME": "/tmp/codex home"],
                capturedAt: 123,
                source: "process"
            )
        )
        let codexFork = SessionRestorableAgentSnapshot(
            kind: .codex,
            sessionId: "019e1eca-ee32-7001-ab30-edcae57430bb",
            workingDirectory: "/Users/example/repo",
            launchCommand: AgentLaunchCommandSnapshot(
                launcher: "codex",
                executablePath: "/Users/example/.bun/bin/codex",
                arguments: [
                    "/Users/example/.bun/bin/codex",
                    "fork",
                    "019dad34-d218-7943-b81a-eddac5c87951",
                    "--model",
                    "gpt-5.4",
                    "--sandbox",
                    "danger-full-access",
                    "stale fork prompt",
                    "--search"
                ],
                workingDirectory: "/Users/example/repo",
                environment: ["CODEX_HOME": "/tmp/codex home"],
                capturedAt: 123,
                source: "process"
            )
        )
        let codexTeams = SessionRestorableAgentSnapshot(
            kind: .codex,
            sessionId: "codex-teams-session",
            workingDirectory: "/Users/example/repo",
            launchCommand: AgentLaunchCommandSnapshot(
                launcher: "codexTeams",
                executablePath: "/usr/local/bin/bmux",
                arguments: [
                    "/usr/local/bin/bmux",
                    "codex-teams",
                    "--model",
                    "gpt-5.4",
                    "--image",
                    "/tmp/team screenshot.png",
                    "--sandbox",
                    "danger-full-access",
                    "initial prompt should not replay"
                ],
                workingDirectory: "/Users/example/repo",
                environment: ["CODEX_HOME": "/tmp/codex home"],
                capturedAt: 123,
                source: "environment"
            )
        )
        let directOpenCode = SessionRestorableAgentSnapshot(
            kind: .opencode,
            sessionId: "direct-opencode-session-456",
            workingDirectory: "/tmp/direct opencode repo",
            launchCommand: AgentLaunchCommandSnapshot(
                launcher: "opencode",
                executablePath: "/opt/homebrew/bin/opencode",
                arguments: [
                    "/opt/homebrew/bin/opencode",
                    "--model",
                    "anthropic/claude-sonnet-4-6",
                    "--session",
                    "old-session",
                    "--prompt",
                    "old prompt",
                    "--port",
                    "4096",
                    "/tmp/direct opencode repo",
                    "initial prompt"
                ],
                workingDirectory: "/tmp/direct opencode repo",
                environment: ["OPENCODE_CONFIG_DIR": "/tmp/opencode config"],
                capturedAt: 123,
                source: "environment"
            )
        )
        let directOpenCodeFork = SessionRestorableAgentSnapshot(
            kind: .opencode,
            sessionId: "direct-opencode-child-session",
            workingDirectory: "/tmp/direct opencode repo",
            launchCommand: AgentLaunchCommandSnapshot(
                launcher: "opencode",
                executablePath: "/opt/homebrew/bin/opencode",
                arguments: [
                    "/opt/homebrew/bin/opencode",
                    "--session",
                    "direct-opencode-session-456",
                    "--fork",
                    "--model",
                    "anthropic/claude-sonnet-4-6",
                    "--port",
                    "4096",
                    "/tmp/direct opencode repo"
                ],
                workingDirectory: "/tmp/direct opencode repo",
                environment: ["OPENCODE_CONFIG_DIR": "/tmp/opencode config"],
                capturedAt: 123,
                source: "environment"
            )
        )
        let omoOpenCode = SessionRestorableAgentSnapshot(
            kind: .opencode,
            sessionId: "opencode-session-123",
            workingDirectory: "/tmp/opencode repo",
            launchCommand: AgentLaunchCommandSnapshot(
                launcher: "omo",
                executablePath: "/usr/local/bin/bmux",
                arguments: [
                    "/usr/local/bin/bmux",
                    "omo",
                    "--model",
                    "anthropic/claude-sonnet-4-6",
                    "/tmp/opencode repo",
                    "initial prompt"
                ],
                workingDirectory: "/tmp/opencode repo",
                environment: ["OPENCODE_CONFIG_DIR": "/tmp/opencode config"],
                capturedAt: 123,
                source: "environment"
            )
        )
        let omoOpenCodeFork = SessionRestorableAgentSnapshot(
            kind: .opencode,
            sessionId: "opencode-child-session",
            workingDirectory: "/tmp/opencode repo",
            launchCommand: AgentLaunchCommandSnapshot(
                launcher: "omo",
                executablePath: "/usr/local/bin/bmux",
                arguments: [
                    "/usr/local/bin/bmux",
                    "omo",
                    "--session",
                    "opencode-session-123",
                    "--fork",
                    "--model",
                    "anthropic/claude-sonnet-4-6",
                    "/tmp/opencode repo"
                ],
                workingDirectory: "/tmp/opencode repo",
                environment: ["OPENCODE_CONFIG_DIR": "/tmp/opencode config"],
                capturedAt: 123,
                source: "environment"
            )
        )
        let unsupported = SessionRestorableAgentSnapshot(
            kind: .gemini,
            sessionId: "gemini-session",
            workingDirectory: "/tmp/gemini repo",
            launchCommand: AgentLaunchCommandSnapshot(
                launcher: "gemini",
                executablePath: "gemini",
                arguments: ["gemini"],
                workingDirectory: "/tmp/gemini repo",
                environment: nil,
                capturedAt: nil,
                source: nil
            )
        )

        #expect(
            claude.forkCommand ==
            "cd -- '/Users/lawrence/fun' 2>/dev/null || [ ! -d '/Users/lawrence/fun' ] && /bin/sh -c "
                + shellQuotedForTest("'env' 'CLAUDE_CONFIG_DIR=/Users/lawrence/.codex-accounts/claude/_p1775010019397' 'BMUX_PRESERVE_CLAUDE_AUTH_SELECTION_ENV=1' 'BMUX_PRESERVE_CLAUDE_AUTH_SELECTION_ENV_KEYS=CLAUDE_CONFIG_DIR' \"$([ -x \"${BMUX_CLAUDE_WRAPPER_SHIM:-}\" ] && printf '%s' \"$BMUX_CLAUDE_WRAPPER_SHIM\" || printf claude)\" '--resume' '24ec0052-450c-4914-b1dd-2ee80d4bc84b' '--fork-session' '--dangerously-load-development-channels' 'server:custom-dev-channel' '--dangerously-skip-permissions'")
        )
        #expect(
            claudeFork.forkCommand ==
            "cd -- '/Users/lawrence/fun' 2>/dev/null || [ ! -d '/Users/lawrence/fun' ] && /bin/sh -c "
                + shellQuotedForTest("'env' 'CLAUDE_CONFIG_DIR=/Users/lawrence/.codex-accounts/claude/_p1775010019397' 'BMUX_PRESERVE_CLAUDE_AUTH_SELECTION_ENV=1' 'BMUX_PRESERVE_CLAUDE_AUTH_SELECTION_ENV_KEYS=CLAUDE_CONFIG_DIR' \"$([ -x \"${BMUX_CLAUDE_WRAPPER_SHIM:-}\" ] && printf '%s' \"$BMUX_CLAUDE_WRAPPER_SHIM\" || printf claude)\" '--resume' 'claude-fork-child' '--fork-session' '--model' 'sonnet' '--dangerously-skip-permissions'")
        )
        #expect(
            codex.forkCommand ==
            "cd -- '/Users/example/repo' 2>/dev/null || [ ! -d '/Users/example/repo' ] && 'env' 'CODEX_HOME=/tmp/codex home' '/Users/example/.bun/bin/codex' 'fork' '019dad34-d218-7943-b81a-eddac5c87951' '--model' 'gpt-5.4' '--sandbox' 'danger-full-access' '--ask-for-approval' 'never' '--search'"
        )
        #expect(
            codexWithImage.forkCommand ==
            "cd -- '/Users/example/repo' 2>/dev/null || [ ! -d '/Users/example/repo' ] && 'env' 'CODEX_HOME=/tmp/codex home' '/Users/example/.bun/bin/codex' 'fork' '019image-session' '--model' 'gpt-5.4'"
        )
        #expect(
            codexFork.forkCommand ==
            "cd -- '/Users/example/repo' 2>/dev/null || [ ! -d '/Users/example/repo' ] && 'env' 'CODEX_HOME=/tmp/codex home' '/Users/example/.bun/bin/codex' 'fork' '019e1eca-ee32-7001-ab30-edcae57430bb' '--model' 'gpt-5.4' '--sandbox' 'danger-full-access' 'stale fork prompt' '--search'"
        )
        #expect(
            codexTeams.forkCommand ==
            "cd -- '/Users/example/repo' 2>/dev/null || [ ! -d '/Users/example/repo' ] && 'env' 'CODEX_HOME=/tmp/codex home' '/usr/local/bin/bmux' 'codex-teams' 'fork' 'codex-teams-session' '--model' 'gpt-5.4' '--sandbox' 'danger-full-access'"
        )
        #expect(
            directOpenCode.forkCommand ==
            "cd -- '/tmp/direct opencode repo' 2>/dev/null || [ ! -d '/tmp/direct opencode repo' ] && 'env' 'OPENCODE_CONFIG_DIR=/tmp/opencode config' '/opt/homebrew/bin/opencode' '--session' 'direct-opencode-session-456' '--fork' '--model' 'anthropic/claude-sonnet-4-6' '--port' '4096' '/tmp/direct opencode repo'"
        )
        #expect(
            directOpenCodeFork.forkCommand ==
            "cd -- '/tmp/direct opencode repo' 2>/dev/null || [ ! -d '/tmp/direct opencode repo' ] && 'env' 'OPENCODE_CONFIG_DIR=/tmp/opencode config' '/opt/homebrew/bin/opencode' '--session' 'direct-opencode-child-session' '--fork' '--model' 'anthropic/claude-sonnet-4-6' '--port' '4096' '/tmp/direct opencode repo'"
        )
        #expect(
            omoOpenCode.forkCommand ==
            "cd -- '/tmp/opencode repo' 2>/dev/null || [ ! -d '/tmp/opencode repo' ] && 'env' 'OPENCODE_CONFIG_DIR=/tmp/opencode config' '/usr/local/bin/bmux' 'omo' '--session' 'opencode-session-123' '--fork' '--model' 'anthropic/claude-sonnet-4-6' '/tmp/opencode repo'"
        )
        #expect(
            omoOpenCodeFork.forkCommand ==
            "cd -- '/tmp/opencode repo' 2>/dev/null || [ ! -d '/tmp/opencode repo' ] && 'env' 'OPENCODE_CONFIG_DIR=/tmp/opencode config' '/usr/local/bin/bmux' 'omo' '--session' 'opencode-child-session' '--fork' '--model' 'anthropic/claude-sonnet-4-6' '/tmp/opencode repo'"
        )
        #expect(unsupported.forkCommand == nil)
    }

    @Test(arguments: [false, true], [false, true])
    func capturedForkTagsAreReplayedOnlyWhenForking(teams: Bool, resume: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("fork-command-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let cwd = root.appendingPathComponent("project's directory")
        try FileManager.default.createDirectory(at: cwd, withIntermediateDirectories: true)
        let executable = root.appendingPathComponent("owned agent")
        try #"""
        #!/bin/sh
        printf '%s\0' "$PWD" "$CODEX_HOME" "$@"
        """#.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let sessionID = "019e1eca-ee32-7001-ab30-edcae57430bb"
        let prefix = teams ? ["codex-teams"] : []
        let options = ["--model", "gpt-5.4", "--sandbox", "danger-full-access"]
        let snapshot = SessionRestorableAgentSnapshot(
            kind: .codex, sessionId: sessionID, workingDirectory: cwd.path,
            launchCommand: AgentLaunchCommandSnapshot(
                launcher: teams ? "codexTeams" : "codex", executablePath: executable.path,
                arguments: [executable.path] + prefix
                    + ["fork", "019dad34-d218-7943-b81a-eddac5c87951"]
                    + options + ["stale fork prompt", "--search"],
                workingDirectory: cwd.path, environment: ["CODEX_HOME": root.appendingPathComponent("codex home").path],
                capturedAt: 123, source: "process"
            )
        )
        let command = try #require(resume ? snapshot.resumeCommand : snapshot.forkCommand)
        let result = try await ShellContractProcess(root: root).run(
            executable: "/bin/sh", arguments: ["-c", command],
            environment: ["HOME": root.path, "CFFIXED_USER_HOME": root.path, "PATH": "/usr/bin:/bin"]
        )
        #expect(result.status == 0, "\(result.stderr)")
        let fields = result.stdout.components(separatedBy: "\0")
        let actualDirectory = URL(fileURLWithPath: try #require(fields.first)).resolvingSymlinksInPath()
        #expect(actualDirectory == cwd.resolvingSymlinksInPath())
        let commandArguments: [String]
        if resume {
            commandArguments = ["resume", sessionID, "-c", "check_for_update_on_startup=false"]
                + options + ["--search"]
        } else {
            commandArguments = ["fork", sessionID] + options + ["stale fork prompt", "--search"]
        }
        let expectedArguments: [String] = prefix + commandArguments
        // Captured fork tags are intentionally replayed on re-fork (#6803), never on resume.
        let actualFields: [String] = Array(fields.dropFirst())
        let expectedFields: [String] = [root.appendingPathComponent("codex home").path] + expectedArguments + [""]
        #expect(actualFields == expectedFields)
    }

    private func shellQuotedForTest(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
