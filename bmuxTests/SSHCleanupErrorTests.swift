import BmuxFoundation
import Foundation
import Testing

@Suite
final class SSHCleanupErrorTests {
    @Test(arguments: [
        "persistent SSH PTY session is no longer running",
        "remote PTY input is temporarily backed up",
        "remote daemon did not respond in time",
        "remote daemon does not support persistent SSH PTY sessions; reconnect the remote workspace to update bmux",
        "remote connection is not active",
        "remote daemon is not ready",
        "missing workspace_id in SSH PTY session list response",
        "missing session_id in SSH PTY session list response",
        "remote PTY operation failed",
    ])
    func preservesCanonicalDaemonError(message: String) async throws {
        try await runCleanup(responseError: message, expected: message)
    }

    @Test
    func missingSessionReportsNotRunningWithoutClosingAnything() async throws {
        try await runCleanup(responseError: nil, expected: "persistent SSH PTY session is no longer running")
    }

    @Test(arguments: [
        ("private token at /Users/person/secret", "remote PTY operation failed"),
        ("pty_session_not_found: private details", "persistent SSH PTY session is no longer running"),
        ("pty.write.notification unsupported", "remote daemon does not support persistent SSH PTY sessions; reconnect the remote workspace to update bmux"),
        ("could not allocate a remote PTY: /dev/ptmx denied", "could not allocate a remote PTY: /dev/ptmx denied"),
    ])
    func preservesSanitizationPolicy(input: String, expected: String) async throws {
        try await runCleanup(responseError: input, expected: expected)
    }

    private func runCleanup(responseError: String?, expected: String) async throws {
        let root = URL(fileURLWithPath: "/tmp").appendingPathComponent("ssh-cleanup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let socketPath = root.appendingPathComponent("socket").path
        let server = CLISocketFixture(path: socketPath) { line in
            let request = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            let id = try #require(request["id"] as? String)
            let method = try #require(request["method"] as? String)
            try #require(method == "workspace.remote.pty_sessions", "Unexpected mutation: \(method)")
            let params = try #require(request["params"] as? [String: Any])
            #expect(params["all_workspaces"] as? Bool == true)
            let errors: [[String: Any]] = responseError.map { [["workspace_id": "workspace:remote", "error": $0]] } ?? []
            let response: [String: Any] = [
                "id": id, "ok": true, "result": ["sessions": [], "errors": errors],
            ]
            return String(decoding: try JSONSerialization.data(withJSONObject: response), as: UTF8.self)
        }
        let cli = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let stdout = root.appendingPathComponent("stdout")
        let stderr = root.appendingPathComponent("stderr")
        let runner = CommandRunner(environment: [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_SOCKET_PATH": socketPath,
            "BMUX_CLI_SENTRY_DISABLED": "1",
        ])
        let (result, commands) = try await server.capture {
            // Files keep pipe-reader tasks from starving the async socket fixture.
            // Positional parameters preserve paths without shell interpolation.
            await runner.run(directory: root.path, executable: "/bin/sh", arguments: [
                "-c", "exec \"$1\" ssh-session-cleanup --all-workspaces --session-id ssh-session-gone > \"$2\" 2> \"$3\"",
                "ssh-cleanup", cli, stdout.path, stderr.path,
            ], timeout: 5)
        }
        try #require(!result.timedOut)
        try #require(result.executionError == nil)
        let errorText = try String(contentsOf: stderr, encoding: .utf8)
        #expect(result.exitStatus == 1, "\(errorText)")
        #expect(try String(contentsOf: stdout, encoding: .utf8).isEmpty)
        #expect(commands.count == 1)
        let count = responseError == nil ? 1 : 2
        #expect(errorText.contains("ssh-session-cleanup failed for \(count) persisted SSH PTY session"))
        let target = responseError == nil ? "ssh-session-gone" : "ssh-session-gone workspace=workspace:remote"
        #expect(errorText.contains("- \(target): \(expected)\n"), "\(errorText)")
        #expect(!errorText.contains("private token"))
    }
}
