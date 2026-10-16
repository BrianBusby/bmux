import Foundation
import Testing

/// Owns one feed producer, authenticated socket, and all paths through joined completion.
final class AgentFeedContractFixture: Sendable {
    enum Phase: String, Sendable { case kiro, codex }
    let root: URL
    let workspace = "33333333-3333-3333-3333-333333333333"
    let surface = "44444444-4444-4444-4444-444444444444"
    private let cli: String
    private let phase: Phase

    init(cli: String, phase: Phase) throws {
        self.cli = cli
        self.phase = phase
        root = URL(fileURLWithPath: "/tmp/feed-contract-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        do { try FileManager.default.removeItem(at: root) }
        catch { Issue.record(error, "Could not remove owned agent feed contract directory") }
    }

    func run(payload: [String: Any]) async throws -> (output: ShellContractProcess.Result, feeds: [String]) {
        let input = root.appendingPathComponent("input")
        try JSONSerialization.data(withJSONObject: payload).write(to: input)
        let socket = root.appendingPathComponent("sock").path
        let password = "owned-feed-contract-password"
        var environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path, "PWD": root.path,
            "XDG_CONFIG_HOME": root.path, "XDG_DATA_HOME": root.path,
            "XDG_STATE_HOME": root.path, "XDG_CACHE_HOME": root.path, "TMPDIR": root.path,
            "CODEX_HOME": root.appendingPathComponent("codex").path, "KIRO_HOME": root.path,
            "BMUX_PROVENANCE_HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_UI_TEST_MODE": "1",
            "BMUX_SOCKET_PATH": socket, "BMUX_SOCKET_PASSWORD": password,
            "BMUX_WORKSPACE_ID": workspace, "BMUX_SURFACE_ID": surface,
            "BMUX_AGENT_HOOK_STATE_DIR": root.path,
            "BMUX_CLI_SENTRY_DISABLED": "1", "BMUX_CLAUDE_HOOK_SENTRY_DISABLED": "1",
        ]
        let arguments: [String]
        switch phase {
        case .kiro:
            environment["BMUX_KIRO_PID"] = "525252"
            environment["BMUX_KIRO_NOTIFICATION_LEVEL"] = "standard"
            arguments = ["hooks", "feed", "--source", "kiro", "--event", "preToolUse"]
        case .codex:
            environment["BMUX_CODEX_PID"] = "626262"
            // This feed contract excludes parent association/monitor composition, covered separately.
            environment["BMUX_AGENT_HOOK_SUPPRESS_VISIBLE_MUTATIONS"] = "true"
            arguments = ["hooks", "codex", "prompt-submit"]
        }
        let (events, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        defer { signal.finish() }
        let server = CLISocketFixture(path: socket) { [phase, surface] line in
            if line.hasPrefix("auth ") {
                try #require(line == "auth \(password)")
                return "OK"
            }
            let request = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            let method = try #require(request["method"] as? String)
            if method == "feed.push" {
                signal.yield(())
                if phase == .codex {
                    #expect(request["id"] == nil)
                    return nil // One-way telemetry does not consume a feed response.
                }
                let id = try #require(request["id"] as? String)
                return try Self.response(id: id, result: [
                    "status": "resolved", "decision": ["kind": "permission", "mode": "deny"],
                ])
            }
            try #require(phase == .codex, "Kiro should send only the actionable feed request")
            let id = try #require(request["id"] as? String)
            switch method {
            case "surface.list":
                return try Self.response(id: id, result: ["surfaces": [["id": surface, "ref": "surface:1", "focused": true]]])
            case "workspace.set_auto_title":
                return try Self.response(id: id, result: ["enabled": false]) // Prevent detached naming work.
            default:
                // Preserve the original rejection of unrelated lifecycle queries.
                return String(decoding: try JSONSerialization.data(withJSONObject: [
                    "id": id, "ok": false,
                    "error": ["code": "unrecognized_method", "message": "unexpected method: \(method)"],
                ]), as: UTF8.self)
            }
        }
        let runner = ShellContractProcess(root: root, deadline: .seconds(CLIProcessTestTimeout().seconds(5)))
        let (outcome, commands) = try await server.capture { [cli] in
            // Producer failure is rethrown only after its socket bytes and descriptors are drained/joined.
            do {
                return Result<ShellContractProcess.Result, any Error>.success(try await runner.run(
                    executable: "/bin/sh", arguments: [
                        "-c", "input=$1; shift; exec \"$@\" <\"$input\"", "feed-contract", input.path,
                        cli, "--socket", socket, "--password", password,
                    ] + arguments, environment: environment
                ))
            } catch { return .failure(error) }
        }
        #expect(!FileManager.default.fileExists(atPath: socket))
        let output: ShellContractProcess.Result
        do { output = try outcome.get() }
        catch {
            Issue.record(error, "\(phase.rawValue) producer failed after \(commands.count) joined protocol frames")
            throw error
        }
        try await waitForFeed(events, deadline: .seconds(5))
        #expect(commands.contains { $0.hasPrefix("auth ") })
        return (output, commands.filter { !$0.hasPrefix("auth ") })
    }

    private func waitForFeed(_ events: AsyncStream<Void>, deadline: Duration) async throws {
        let end = ContinuousClock.now.advanced(by: deadline)
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await _ in events { return }
                throw CancellationError()
            }
            group.addTask {
                // Retain the original separate five-second server observation failure bound.
                try await ContinuousClock().sleep(until: end)
                throw Failure.feedNotObserved
            }
            _ = try await group.next()
        }
        try Task.checkCancellation()
    }

    private static func response(id: String, result: [String: Any]) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: ["id": id, "ok": true, "result": result]), as: UTF8.self)
    }

    private enum Failure: Error { case feedNotObserved }
}
