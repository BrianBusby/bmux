import Foundation
import Testing

@Suite(.serialized)
final class CLISessionForkDiagnosticTests {
    @Test func testSessionsListForkDiagnosticsUseForkCommandBuilder() async throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-sessions-list-fork-builder-\(UUID().uuidString)", isDirectory: true)
        let stateDir = root.appendingPathComponent("state", isDirectory: true)
        let codexHome = root.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record(error, "Could not remove owned fork-diagnostic fixture directory") }
        }
        try FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)

        let sessionId = "019ee74a-3c84-7de3-84f1-ece32f4ecfbb"
        let workspaceId = "33B0D372-292E-42BF-97B6-E37CCA79AB84"
        let surfaceId = "A2AECAA9-EE1C-4999-B7A9-EE4BB4CDA5D8"
        let store: [String: Any] = [
            "version": 1,
            "sessions": [
                sessionId: [
                    "sessionId": sessionId,
                    "workspaceId": workspaceId,
                    "surfaceId": surfaceId,
                    "cwd": "/tmp/bmux/debug",
                    "pid": 987_654_321,
                    "startedAt": 1_781_996_800.0,
                    "updatedAt": 1_781_996_867.0,
                    "launchCommand": [
                        "launcher": "codex",
                        "executablePath": "/usr/local/bin/codex",
                        "arguments": ["/usr/local/bin/codex", "exec", "make", "test"],
                        "workingDirectory": "/tmp/bmux/debug",
                        "environment": [
                            "CODEX_HOME": codexHome.path,
                        ],
                        "source": "environment",
                    ],
                ]
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: store, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: stateDir.appendingPathComponent("codex-hook-sessions.json"), options: .atomic)

        let result = try await ShellContractProcess(root: root, deadline: .seconds(5)).run(
            executable: cliPath,
            arguments: ["sessions", "list", "--agent", "codex", "--session", sessionId, "--json"],
            environment: [
                "HOME": root.path, "CFFIXED_USER_HOME": root.path,
                "XDG_CONFIG_HOME": root.path, "XDG_DATA_HOME": root.path,
                "XDG_STATE_HOME": root.path, "XDG_CACHE_HOME": root.path,
                "CLAUDE_CONFIG_DIR": root.appendingPathComponent("claude").path,
                "CODEX_HOME": codexHome.path,
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_UI_TEST_MODE": "1",
                "BMUX_SOCKET_PASSWORD": "owned-fork-diagnostics-fixture",
                "BMUX_CLI_SENTRY_DISABLED": "1", "BMUX_AGENT_HOOK_STATE_DIR": stateDir.path,
            ]
        )

        // Throwing, joined completion preserves the original five-second no-timeout assertion.
        #expect(result.status == 0, Comment(rawValue: result.stdout))
        let outputData = try #require(result.stdout.data(using: .utf8))
        let object = try #require(JSONSerialization.jsonObject(with: outputData) as? [String: Any])
        #expect(object["total_matches"] as? Int == 1)
        let sessions = try #require(object["sessions"] as? [[String: Any]])
        let session = try #require(sessions.first)
        #expect(session["session_id"] as? String == sessionId)
        #expect(session["fork_supported"] as? Bool == false)
        #expect(session["fork_unavailable_reason"] as? String == "agent_has_no_fork_command")
        #expect(session["fork_startup_input_available"] as? Bool == false)
        #expect(session["stale_pid_blocks_restore_in_0_64_17"] as? Bool == true)
    }
}
