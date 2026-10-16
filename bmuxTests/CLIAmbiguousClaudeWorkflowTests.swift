import Foundation
import Testing

final class CLIAmbiguousClaudeWorkflowTests {
    @Test func rejectsAmbiguousClaudeWorkflowContainerTranscripts() async throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-sessions-list-claude-workflow-\(UUID().uuidString)", isDirectory: true)
        let stateDir = root.appendingPathComponent("state", isDirectory: true)
        let repoDir = root.appendingPathComponent("repo", isDirectory: true)
        let claudeConfigDir = root.appendingPathComponent("claude-config", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record(error, "Could not remove owned sessions-list directory") }
        }
        try FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)

        let containerSessionId = "aaaaaaaa-1111-1111-1111-aaaaaaaaaaaa"
        let siblingSessionIds = ["bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb", "cccccccc-3333-3333-3333-cccccccccccc"]
        let projectDirName = repoDir.path
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ".", with: "-")
        let projectDir = claudeConfigDir
            .appendingPathComponent("projects", isDirectory: true)
            .appendingPathComponent(projectDirName, isDirectory: true)
        let workflowContainerURL = projectDir.appendingPathComponent(containerSessionId, isDirectory: true)
        try FileManager.default.createDirectory(at: workflowContainerURL, withIntermediateDirectories: true)
        for siblingSessionId in siblingSessionIds {
            try "{}\n".write(
                to: projectDir.appendingPathComponent("\(siblingSessionId).jsonl", isDirectory: false),
                atomically: true,
                encoding: .utf8
            )
        }

        let store: [String: Any] = [
            "version": 1,
            "sessions": [
                containerSessionId: [
                    "sessionId": containerSessionId,
                    "workspaceId": "33B0D372-292E-42BF-97B6-E37CCA79AB84",
                    "surfaceId": "A2AECAA9-EE1C-4999-B7A9-EE4BB4CDA5D8",
                    "cwd": repoDir.path,
                    "transcriptPath": workflowContainerURL.path,
                    "isRestorable": false,
                    "startedAt": 1_781_996_800.0,
                    "updatedAt": 1_781_996_867.0,
                    "launchCommand": [
                        "launcher": "claude",
                        "executablePath": "/usr/local/bin/claude",
                        "arguments": ["/usr/local/bin/claude"],
                        "workingDirectory": repoDir.path,
                        "environment": ["CLAUDE_CONFIG_DIR": claudeConfigDir.path],
                        "source": "environment",
                    ],
                ]
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: store, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: stateDir.appendingPathComponent("claude-hook-sessions.json"), options: .atomic)

        let result = try await ShellContractProcess(root: root, deadline: .seconds(5)).run(
            executable: cliPath,
            arguments: ["sessions", "list", "--agent", "claude", "--session", containerSessionId, "--json"],
            environment: [
                "HOME": root.path, "CFFIXED_USER_HOME": root.path,
                "XDG_CONFIG_HOME": root.path, "XDG_DATA_HOME": root.path,
                "XDG_STATE_HOME": root.path, "XDG_CACHE_HOME": root.path,
                "CLAUDE_CONFIG_DIR": claudeConfigDir.path,
                "CODEX_HOME": root.appendingPathComponent("codex").path,
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_UI_TEST_MODE": "1",
                "BMUX_SOCKET_PASSWORD": "owned-sessions-fixture",
                "BMUX_CLI_SENTRY_DISABLED": "1", "BMUX_AGENT_HOOK_STATE_DIR": stateDir.path,
            ]
        )

        // A throwing, joined five-second run preserves the original no-timeout assertion.
        #expect(result.status == 0, Comment(rawValue: result.stderr))
        let outputData = try #require(result.stdout.data(using: .utf8))
        let object = try #require(JSONSerialization.jsonObject(with: outputData) as? [String: Any])
        let sessions = try #require(object["sessions"] as? [[String: Any]])
        let session = try #require(sessions.first)
        #expect(session["session_id"] as? String == containerSessionId)
        #expect(session["hook_record_restorable"] as? Bool == false)
        #expect(session["fork_command_available"] as? Bool == false)
        #expect(session["fork_supported"] as? Bool == false)
        #expect(session["fork_unavailable_reason"] as? String == "record_marked_non_restorable")
    }

}
