import Foundation
import Testing

/// Owns one Claude session store and joins each producer before draining its socket phase.
@MainActor
final class ClaudeSessionPhaseFixture {
    let root: URL
    let workspaceId = "11111111-1111-1111-1111-111111111111"
    let surfaceId = "22222222-2222-2222-2222-222222222222"
    var commands: [String] = []
    private let cli: String

    init(cli: String) throws {
        self.cli = cli
        root = URL(fileURLWithPath: "/tmp/cl-phase-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func cleanup() {
        do { try FileManager.default.removeItem(at: root) }
        catch { Issue.record(error, "Could not remove owned Claude session fixture directory") }
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    func run(arguments: [String], standardInput: String) async throws -> ShellContractProcess.Result {
        let input = root.appendingPathComponent("input")
        try Data(standardInput.utf8).write(to: input)
        let socket = root.appendingPathComponent("sock").path
        let environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path, "PWD": root.path,
            "XDG_CONFIG_HOME": root.path, "XDG_STATE_HOME": root.path,
            "XDG_CACHE_HOME": root.path, "TMPDIR": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_UI_TEST_MODE": "1",
            "BMUX_SOCKET_PATH": socket, "BMUX_SOCKET_PASSWORD": "owned-fixture-password",
            "BMUX_WORKSPACE_ID": workspaceId, "BMUX_SURFACE_ID": surfaceId,
            "BMUX_CLAUDE_HOOK_STATE_PATH": root.appendingPathComponent("claude-hook-sessions.json").path,
            "BMUX_CLI_SENTRY_DISABLED": "1", "BMUX_CLAUDE_HOOK_SENTRY_DISABLED": "1"
        ]
        let server = CLISocketFixture(path: socket, response: responder())
        // Retain the original five-second child deadline; timeout joins the child.
        let runner = ShellContractProcess(root: root, deadline: .seconds(5))
        let (outcome, phaseCommands) = try await server.capture { @Sendable [cli] in
            // Capture failure as data so queued requests are drained before rethrowing.
            do {
                return .success(try await runner.run(executable: "/bin/sh", arguments: [
                    "-c", "input=$1; shift; exec \"$@\" <\"$input\"",
                    "claude-phase", input.path, cli
                ] + arguments, environment: environment)) as Result<ShellContractProcess.Result, Error>
            } catch { return .failure(error) }
        }
        commands += phaseCommands.filter { !$0.hasPrefix("auth ") }
        #expect(!FileManager.default.fileExists(atPath: socket))
        do { return try outcome.get() }
        catch {
            let methods = phaseCommands.map { line -> String in
                if line.hasPrefix("auth ") { return "auth" }
                if let payload = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                   let method = payload["method"] as? String { return method }
                return String(line.prefix { $0 != " " })
            }
            Issue.record(error, "Claude phase failed after joined requests: \(methods)")
            throw error
        }
    }

    private func responder() -> @Sendable (String) throws -> String? {
        let workspace = workspaceId, surface = surfaceId
        return { line in
            if line.hasPrefix("auth ") {
                try #require(line == "auth owned-fixture-password")
                return "OK"
            }
            guard line.hasPrefix("{") else {
                try #require(["set_agent_pid ", "set_agent_lifecycle ", "set_status ",
                    "clear_status ", "clear_notifications ", "notify_target_async "].contains { line.hasPrefix($0) })
                return "OK"
            }
            let request = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            let method = try #require(request["method"] as? String)
            if method == "feed.push", request["id"] == nil { return nil }
            let id = try #require(request["id"] as? String)
            let params = try #require(request["params"] as? [String: Any])
            let result: [String: Any]
            switch method {
            case "surface.list":
                #expect(params["workspace_id"] as? String == workspace)
                result = ["surfaces": [["id": surface, "ref": "surface:1", "index": 1, "focused": true]]]
            case "system.top": result = ["windows": []]
            case "debug.terminals": result = ["terminals": []]
            case "surface.resume.set":
                #expect(params["workspace_id"] as? String == workspace)
                #expect(params["surface_id"] as? String == surface)
                result = ["resume_binding": [:]]
            default: throw NSError(domain: "Unexpected Claude method \(method)", code: 1)
            }
            return String(decoding: try JSONSerialization.data(withJSONObject: ["id": id, "ok": true, "result": result]), as: UTF8.self)
        }
    }
}
