import Foundation
import Testing

/// Owns the Kiro lifecycle RPCs and unanswered feed connection until producer and server exit.
final class GenericLifecycleFeedNoResponseFixture: Sendable {
    let root: URL
    let cli: String

    init(cli: String) throws {
        self.cli = cli
        root = URL(fileURLWithPath: "/tmp/kiro-hook-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        do { try FileManager.default.removeItem(at: root) }
        catch { Issue.record(error, "Could not remove owned Kiro lifecycle fixture directory") }
    }

    func run() async throws -> (output: ShellContractProcess.Result, observed: Bool, commands: [String]) {
        let socket = root.appendingPathComponent("sock").path
        let input = root.appendingPathComponent("input")
        let workspace = "33333333-3333-3333-3333-333333333333"
        let surface = "44444444-4444-4444-4444-444444444444"
        let password = "test-password"
        let launchArguments = [
            "/Users/example/.cargo/bin/kiro-cli", "chat", "--agent", "bmux", "--resume-id", "old-session",
        ]
        let payload = #"{"session_id":"kiro-lifecycle-no-response","cwd":"\#(root.path)","hook_event_name":"SessionStart"}"#
        try Data(payload.utf8).write(to: input)
        let environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path, "PWD": root.path,
            "XDG_CONFIG_HOME": root.path, "XDG_STATE_HOME": root.path,
            "XDG_CACHE_HOME": root.path, "TMPDIR": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_UI_TEST_MODE": "1",
            "BMUX_SOCKET_PATH": socket, "BMUX_SOCKET_PASSWORD": password,
            "BMUX_WORKSPACE_ID": workspace, "BMUX_SURFACE_ID": surface,
            "BMUX_AGENT_HOOK_STATE_DIR": root.path, "BMUX_AGENT_LAUNCH_KIND": "kiro",
            "BMUX_AGENT_LAUNCH_EXECUTABLE": "/Users/example/.cargo/bin/kiro-cli",
            "BMUX_AGENT_LAUNCH_ARGV_B64": Data(launchArguments.joined(separator: "\0").utf8).base64EncodedString(),
            "BMUX_AGENT_LAUNCH_CWD": root.path,
            "BMUX_CLI_SENTRY_DISABLED": "1", "BMUX_CLAUDE_HOOK_SENTRY_DISABLED": "1",
            "BMUX_DEBUG_LOG": root.appendingPathComponent("debug.log").path,
        ]
        let (events, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        defer { signal.finish() }
        let server = CLISocketFixture(path: socket) { line in
            if line.hasPrefix("auth ") {
                guard line == "auth \(password)" else {
                    throw NSError(domain: "KiroLifecycleAuthenticationMismatch", code: 1)
                }
                return "OK"
            }
            guard let request = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else {
                return "OK" // Existing plain lifecycle commands retain their original response.
            }
            let id = request["id"] as? String
            guard let method = request["method"] as? String else {
                return try Self.malformedResponse(id: id, raw: line)
            }
            if method == "feed.push" {
                #expect(request["id"] == nil)
                let parameters = try #require(request["params"] as? [String: Any])
                #expect(parameters["wait_timeout_seconds"] as? Int == 0)
                signal.yield(())
                return nil // Separate feed authentication must not become a feed response.
            }
            guard let id else { return try Self.malformedResponse(id: nil, raw: line) }
            switch method {
            case "surface.list":
                return try Self.response([
                    "id": id, "ok": true,
                    "result": ["surfaces": [["id": surface, "ref": "surface:1", "focused": true]]],
                ])
            case "surface.resume.set":
                return try Self.response(["id": id, "ok": true, "result": ["ok": true]])
            default:
                return try Self.response([
                    "id": id, "ok": false,
                    "error": ["code": "unrecognized_method", "message": "unexpected method: \(method)"],
                ])
            }
        }
        let runner = ShellContractProcess(root: root, deadline: .seconds(3))
        let (outcome, commands) = try await server.capture {
            // Preserve errors until the producer exits and final queued requests are drained.
            do {
                return Result<ShellContractProcess.Result, any Error>.success(try await runner.run(
                    executable: "/bin/sh", arguments: [
                        "-c", "exec \"$1\" --socket \"$2\" hooks kiro session-start <\"$3\"",
                        "kiro-hook", cli, socket, input.path,
                    ], environment: environment
                ))
            } catch { return .failure(error) }
        }
        #expect(!FileManager.default.fileExists(atPath: socket))
        let output: ShellContractProcess.Result
        do { output = try outcome.get() }
        catch {
            let authentications = commands.filter { $0.hasPrefix("auth ") }.count
            Issue.record(error, "Kiro lifecycle failed after \(authentications) authentication and \(commands.count - authentications) command requests")
            throw error
        }
        return (output, try await observe(events), commands)
    }

    private func observe(_ events: AsyncStream<Void>) async throws -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        return try await withThrowingTaskGroup(of: Bool.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await _ in events { return true }
                return false
            }
            group.addTask {
                // Preserve the original separate five-second feed observation failure bound.
                try await ContinuousClock().sleep(until: deadline)
                return false
            }
            return try await group.next() ?? false
        }
    }

    private static func malformedResponse(id: String?, raw: String) throws -> String {
        try response([
            "id": id ?? "unknown", "ok": false,
            "error": ["code": "malformed_request", "message": "invalid or non-JSON payload", "raw": raw],
        ])
    }

    private static func response(_ payload: [String: Any]) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: payload), as: UTF8.self)
    }
}
