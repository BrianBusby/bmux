import BmuxFoundation
import Foundation
import Testing

/// Isolates hook input, transcript discovery, persistence and the CLI process.
final class CodexStopHookFixture {
    let root: URL
    let workspaceID = "11111111-1111-1111-1111-111111111111"
    let surfaceID = "22222222-2222-2222-2222-222222222222"
    var codexHome: URL { root.appendingPathComponent("codex-home", isDirectory: true) }

    init() throws {
        // Keep AF_UNIX paths below Darwin's 104-byte limit regardless of TMPDIR.
        root = URL(fileURLWithPath: "/tmp").appendingPathComponent("codex-stop-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    func sessionDirectory() throws -> URL {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = calendar.dateComponents([.year, .month, .day], from: Date())
        let directory = codexHome.appendingPathComponent(String(
            format: "sessions/%04d/%02d/%02d", parts.year!, parts.month!, parts.day!
        ))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func run(input: String) async throws -> [String] {
        let inputURL = root.appendingPathComponent("hook-input.json")
        try input.write(to: inputURL, atomically: true, encoding: .utf8)
        let stdoutURL = root.appendingPathComponent("stdout")
        let stderrURL = root.appendingPathComponent("stderr")
        let socketPath = root.appendingPathComponent("socket").path
        let server = CodexStopMockServer(path: socketPath, responder: CodexStopMockResponse(
            workspaceID: workspaceID, surfaceID: surfaceID
        ))
        let cli = try BundledCLITestSupport.bundledCLIPath(for: BundledCLILinkageTests.self)
        let runner = CommandRunner(environment: [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "CODEX_HOME": codexHome.path,
            "BMUX_SOCKET_PATH": socketPath, "BMUX_WORKSPACE_ID": workspaceID,
            "BMUX_SURFACE_ID": surfaceID, "BMUX_AGENT_HOOK_STATE_DIR": root.path,
            "BMUX_CLI_SENTRY_DISABLED": "1",
        ])
        let (result, commands) = try await server.capture {
            // CommandRunner owns exit/deadline handling; files preserve exact non-TTY I/O
            // without blocking its pipe-reader tasks during parallel socket tests.
            // Positional arguments preserve paths without shell interpolation.
            await runner.run(directory: root.path, executable: "/bin/sh", arguments: [
                "-c", "exec \"$1\" hooks codex stop < \"$2\" > \"$3\" 2> \"$4\"",
                "codex-stop", cli, inputURL.path, stdoutURL.path, stderrURL.path,
            ], timeout: 5)
        }
        try #require(!result.timedOut, "Hook process timed out")
        try #require(result.executionError == nil, "\(result.executionError ?? "")")
        let exitStatus = try #require(result.exitStatus, "Hook process did not report native exit")
        let stdout = try String(contentsOf: stdoutURL, encoding: .utf8)
        let stderr = try String(contentsOf: stderrURL, encoding: .utf8)
        #expect(exitStatus == 0, "\(stderr)")
        #expect(stdout == "{}\n")
        return commands
    }
}
