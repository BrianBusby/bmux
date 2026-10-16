import Foundation
import Testing

@Suite(.serialized)
final class CLIStaleCodexSessionTests {
    @Test func testSessionsListDefaultOmitsStaleCodexRowsWithoutTranscript() async throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-sessions-list-\(UUID().uuidString)", isDirectory: true)
        let stateDir = root.appendingPathComponent("state", isDirectory: true)
        let codexHome = root.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record(error, "Could not remove owned stale-session fixture directory") }
        }
        try FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)

        let activeSessionId = "019ef6ac-e358-7dd2-902d-8492fa0ba2bb"
        let staleSessionId = "019ef5c3-e0a1-7473-a6bf-48bbcf234de0"
        let launchBackedSessionId = "019ef7b0-9c49-700b-9a8c-e831d7d1af3a"
        let savedTranscriptSessionId = "019ef8ac-840d-75bc-ae10-f2e992d05fab"
        let savedTranscript = root.appendingPathComponent("saved-codex-transcript.jsonl", isDirectory: false)
        try #"{"type":"event_msg","payload":{"type":"task_complete"}}"#
            .write(to: savedTranscript, atomically: true, encoding: .utf8)
        let store: [String: Any] = [
            "version": 1,
            "activeSessionsByWorkspace": [
                "workspace-active": [
                    "sessionId": activeSessionId,
                    "updatedAt": 1_782_255_000.0
                ]
            ],
            "activeSessionsBySurface": [
                "surface-active": [
                    "sessionId": activeSessionId,
                    "updatedAt": 1_782_255_000.0
                ]
            ],
            "sessions": [
                activeSessionId: [
                    "sessionId": activeSessionId,
                    "workspaceId": "workspace-active",
                    "surfaceId": "surface-active",
                    "cwd": "/tmp/bmux/active",
                    "startedAt": 1_782_254_900.0,
                    "updatedAt": 1_782_255_000.0
                ],
                staleSessionId: [
                    "sessionId": staleSessionId,
                    "workspaceId": "workspace-stale",
                    "surfaceId": "surface-stale",
                    "cwd": "/tmp/bmux/stale",
                    "startedAt": 1_782_254_950.0,
                    "updatedAt": 1_782_255_010.0
                ],
                launchBackedSessionId: [
                    "sessionId": launchBackedSessionId,
                    "workspaceId": "workspace-launch-backed",
                    "surfaceId": "surface-launch-backed",
                    "cwd": "/tmp/bmux/launch-backed",
                    "startedAt": 1_782_254_960.0,
                    "updatedAt": 1_782_255_020.0,
                    "launchCommand": [
                        "launcher": "codex",
                        "executablePath": "/usr/local/bin/codex",
                        "arguments": ["/usr/local/bin/codex", "--yolo"],
                        "workingDirectory": "/tmp/bmux/launch-backed",
                        "capturedAt": 1_782_254_960.0,
                        "source": "process",
                    ],
                ],
                savedTranscriptSessionId: [
                    "sessionId": savedTranscriptSessionId,
                    "workspaceId": "workspace-saved-transcript",
                    "surfaceId": "surface-saved-transcript",
                    "cwd": "/tmp/bmux/saved-transcript",
                    "transcriptPath": savedTranscript.path,
                    "startedAt": 1_782_254_970.0,
                    "updatedAt": 1_782_255_030.0
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: store, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: stateDir.appendingPathComponent("codex-hook-sessions.json"), options: .atomic)

        let environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path,
            "XDG_CONFIG_HOME": root.path, "XDG_DATA_HOME": root.path,
            "XDG_STATE_HOME": root.path, "XDG_CACHE_HOME": root.path,
            "TMPDIR": root.path, "CODEX_HOME": codexHome.path,
            "CLAUDE_CONFIG_DIR": root.appendingPathComponent("claude").path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_UI_TEST_MODE": "1",
            "BMUX_CLI_SENTRY_DISABLED": "1", "BMUX_AGENT_HOOK_STATE_DIR": stateDir.path,
            "BMUX_SOCKET_PASSWORD": "owned-offline-sessions-proof"
        ]

        // Each throwing, joined call preserves its original plain five-second no-timeout oracle.
        let runner = ShellContractProcess(root: root, deadline: .seconds(5))
        let defaultResult = try await runner.run(
            executable: cliPath,
            arguments: ["sessions", "list", "--agent", "codex", "--json"],
            environment: environment
        )

        #expect(defaultResult.status == 0, "defaultResult status")
        let defaultOutputData = try #require(defaultResult.stdout.data(using: .utf8))
        let defaultObject = try #require(JSONSerialization.jsonObject(with: defaultOutputData) as? [String: Any])
        #expect(defaultObject["total_matches"] as? Int == 3)
        let defaultSessions = try #require(defaultObject["sessions"] as? [[String: Any]])
        #expect(Set(defaultSessions.compactMap { $0["session_id"] as? String }) == [activeSessionId, launchBackedSessionId, savedTranscriptSessionId])
        #expect(defaultSessions.first { $0["session_id"] as? String == launchBackedSessionId }?["launch_backed"] as? Bool == true)
        #expect(defaultSessions.first { $0["session_id"] as? String == savedTranscriptSessionId }?["transcript_backed"] as? Bool == true)

        let cwdResult = try await runner.run(
            executable: cliPath,
            arguments: ["sessions", "list", "--agent", "codex", "--cwd", "/tmp/bmux", "--json"],
            environment: environment
        )

        #expect(cwdResult.status == 0, "cwdResult status")
        let cwdOutputData = try #require(cwdResult.stdout.data(using: .utf8))
        let cwdObject = try #require(JSONSerialization.jsonObject(with: cwdOutputData) as? [String: Any])
        #expect(cwdObject["total_matches"] as? Int == 4)
        let cwdSessions = try #require(cwdObject["sessions"] as? [[String: Any]])
        #expect(Set(cwdSessions.compactMap { $0["session_id"] as? String }) == [activeSessionId, staleSessionId, launchBackedSessionId, savedTranscriptSessionId])

        let allResult = try await runner.run(
            executable: cliPath,
            arguments: ["sessions", "list", "--agent", "codex", "--all", "--json"],
            environment: environment
        )

        #expect(allResult.status == 0, "allResult status")
        let allOutputData = try #require(allResult.stdout.data(using: .utf8))
        let allObject = try #require(JSONSerialization.jsonObject(with: allOutputData) as? [String: Any])
        #expect(allObject["total_matches"] as? Int == 4)
        let allSessions = try #require(allObject["sessions"] as? [[String: Any]])
        #expect(Set(allSessions.compactMap { $0["session_id"] as? String }) == [activeSessionId, staleSessionId, launchBackedSessionId, savedTranscriptSessionId])
    }
}
