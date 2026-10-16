import Foundation
import Testing

final class CLITranscriptBackedClaudeSessionTests {
    @Test func transcriptBackedRecordIsRestorable() async throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-sessions-list-claude-transcript-\(UUID().uuidString)", isDirectory: true)
        let stateDir = root.appendingPathComponent("state", isDirectory: true)
        let repoDir = root.appendingPathComponent("repo", isDirectory: true)
        let transcriptURL = root.appendingPathComponent("claude-session.jsonl", isDirectory: false)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record(error, "Could not remove owned transcript fixture directory") }
        }
        try FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
        try "{}\n".write(to: transcriptURL, atomically: true, encoding: .utf8)

        let sessionId = "claude-transcript-backed-session"
        let workspaceId = "33B0D372-292E-42BF-97B6-E37CCA79AB84"
        let surfaceId = "A2AECAA9-EE1C-4999-B7A9-EE4BB4CDA5D8"
        let store: [String: Any] = [
            "version": 1,
            "sessions": [
                sessionId: [
                    "sessionId": sessionId,
                    "workspaceId": workspaceId,
                    "surfaceId": surfaceId,
                    "cwd": repoDir.path,
                    "transcriptPath": transcriptURL.path,
                    "isRestorable": false,
                    "startedAt": 1_781_996_800.0,
                    "updatedAt": 1_781_996_867.0,
                    "launchCommand": [
                        "launcher": "claude",
                        "executablePath": "/usr/local/bin/claude",
                        "arguments": ["/usr/local/bin/claude"],
                        "workingDirectory": repoDir.path,
                        "source": "environment",
                    ],
                ]
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: store, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: stateDir.appendingPathComponent("claude-hook-sessions.json"), options: .atomic)

        let result = try await ShellContractProcess(root: root, deadline: .seconds(5)).run(
            executable: cliPath,
            arguments: ["sessions", "list", "--agent", "claude", "--session", sessionId, "--json"],
            environment: [
                "HOME": root.path, "CFFIXED_USER_HOME": root.path,
                "XDG_CONFIG_HOME": root.path, "XDG_DATA_HOME": root.path,
                "XDG_STATE_HOME": root.path, "XDG_CACHE_HOME": root.path,
                "CLAUDE_CONFIG_DIR": root.appendingPathComponent("claude").path,
                "CODEX_HOME": root.appendingPathComponent("codex").path,
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_UI_TEST_MODE": "1",
                "BMUX_SOCKET_PASSWORD": "owned-transcript-fixture",
                "BMUX_CLI_SENTRY_DISABLED": "1", "BMUX_AGENT_HOOK_STATE_DIR": stateDir.path,
            ]
        )
        // A throwing, joined five-second run retains the original no-timeout assertion.
        #expect(result.status == 0, Comment(rawValue: result.stdout + result.stderr))
        let outputData = try #require(result.stdout.data(using: .utf8))
        let object = try #require(JSONSerialization.jsonObject(with: outputData) as? [String: Any])
        #expect(object["total_matches"] as? Int == 1)
        let sessions = try #require(object["sessions"] as? [[String: Any]])
        let session = try #require(sessions.first)
        #expect(session["session_id"] as? String == sessionId)
        #expect(session["hook_record_restorable"] as? Bool == true)
        #expect(session["fork_command_available"] as? Bool == true)
        #expect(session["fork_supported"] as? Bool == true)
        #expect(session["fork_unavailable_reason"] as? String == "available")
    }
}
