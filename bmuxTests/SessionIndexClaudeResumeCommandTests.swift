import BMUXAgentLaunch
import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct SessionIndexClaudeResumeCommandTests {
    @Test(arguments: ["claude config", "projects/claude config"])
    func resumePinsSnapshotConfigDirectory(relativeConfigDirectory: String) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("claude-resume-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let config = root.appendingPathComponent(relativeConfigDirectory)
        let transcript = config.appendingPathComponent("projects/-tmp/claude-session-123.jsonl")
        try FileManager.default.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"oauthAccount":{"email":"user@example.com"}}"#.utf8)
            .write(to: config.appendingPathComponent(".claude.json"))
        let entry = makeEntry(transcript: transcript, config: config.path, cwd: nil)
        try await verifyExecution(entry, root: root, config: config.path, arguments: ["--resume", "claude-session-123"])
    }

    @Test
    func resumeOmitsUnconfiguredCanonicalConfigDirectory() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("claude-resume-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let transcript = root.appendingPathComponent(".claude/projects/-tmp-repo/session-123.jsonl")
        try FileManager.default.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
        #expect(ClaudeConfigurationRoot.configuredResumeDirectory(root.appendingPathComponent(".claude").path) == nil)
        let cwd = root.appendingPathComponent("working directory's repo")
        try FileManager.default.createDirectory(at: cwd, withIntermediateDirectories: true)
        let entry = makeEntry(transcript: transcript, config: nil, cwd: cwd.path, sessionID: "session-123", model: "claude-opus-4-7", permission: "default")
        let command = try #require(entry.resumeCommand)
        #expect(!command.contains("CLAUDE_CONFIG_DIR="))
        try await verifyExecution(entry, root: root, config: nil, arguments: [
            "--resume", "session-123", "--model", "claude-opus-4-7", "--permission-mode", "default",
        ])
    }

    @Test
    func resumeChangesToSessionDirectoryBeforeExecuting() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("claude-cwd-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let sessionID = "a22293b7-bcef-4707-8439-2f538c8517a4"
        let transcript = root.appendingPathComponent(".claude/projects/-Users-tiffanysun-fun/\(sessionID).jsonl")
        try FileManager.default.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
        let cwd = root.appendingPathComponent("session working directory")
        try FileManager.default.createDirectory(at: cwd, withIntermediateDirectories: true)
        let entry = makeEntry(transcript: transcript, config: nil, cwd: cwd.path, sessionID: sessionID)
        try await verifyExecution(entry, root: root, config: nil, arguments: ["--resume", sessionID])
    }

    private func makeEntry(
        transcript: URL, config: String?, cwd: String?, sessionID: String = "claude-session-123", model: String? = nil, permission: String? = nil
    ) -> SessionEntry {
        SessionEntry(
            id: "claude-session-123", agent: .claude, sessionId: sessionID, title: "Resume me",
            cwd: cwd, gitBranch: nil, pullRequest: nil, modified: .now, fileURL: transcript,
            specifics: .claude(model: model, permissionMode: permission, configDirectoryForResume: config)
        )
    }

    private func verifyExecution(
        _ entry: SessionEntry, root: URL, config: String?, arguments: [String]
    ) async throws {
        let shim = root.appendingPathComponent("owned claude's shim")
        try """
        #!/bin/sh
        printf '%s\\n' "$PWD" "${CLAUDE_CONFIG_DIR-<unset>}" "${BMUX_PRESERVE_CLAUDE_AUTH_SELECTION_ENV-<unset>}" "${BMUX_PRESERVE_CLAUDE_AUTH_SELECTION_ENV_KEYS-<unset>}" "$@"
        """.write(to: shim, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: shim.path)
        let result = try await ShellContractProcess(root: root).run(
            executable: "/bin/sh", arguments: ["-c", try #require(entry.resumeCommand)],
            environment: ["HOME": root.path, "CFFIXED_USER_HOME": root.path, "PATH": "/usr/bin:/bin", "BMUX_CLAUDE_WRAPPER_SHIM": shim.path]
        )
        #expect(result.status == 0, "\(result.stderr)")
        let output = result.stdout.components(separatedBy: "\n")
        let reportedDirectory = URL(fileURLWithPath: try #require(output.first)).resolvingSymlinksInPath()
        let expectedDirectory = URL(fileURLWithPath: entry.cwd ?? root.path).resolvingSymlinksInPath()
        #expect(reportedDirectory == expectedDirectory)
        let expected = [config ?? "<unset>", config == nil ? "<unset>" : "1", config == nil ? "<unset>" : "CLAUDE_CONFIG_DIR"] + arguments + [""]
        #expect(Array(output.dropFirst()) == expected)
    }
}
