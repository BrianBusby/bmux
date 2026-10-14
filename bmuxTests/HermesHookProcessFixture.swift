import Foundation
import Testing

/// Owns one Hermes session root and joins each hook process and socket phase.
final class HermesHookProcessFixture: Sendable {
    let root: URL
    let workspace = "11111111-1111-1111-1111-111111111111"
    let surface = "22222222-2222-2222-2222-222222222222"
    let cli: String

    init(cli: String) throws {
        self.cli = cli
        root = URL(fileURLWithPath: "/tmp/hermes-hook-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        do { try FileManager.default.removeItem(at: root) }
        catch { Issue.record(error, "Could not remove owned Hermes hook fixture directory") }
    }

    func run(_ subcommand: String, input: String) async throws -> (output: ShellContractProcess.Result, commands: [String]) {
        let inputURL = root.appendingPathComponent("input")
        try Data(input.utf8).write(to: inputURL)
        let socket = root.appendingPathComponent("sock").path
        let environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path, "PWD": root.path,
            "XDG_CONFIG_HOME": root.path, "XDG_STATE_HOME": root.path,
            "XDG_CACHE_HOME": root.path, "TMPDIR": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_UI_TEST_MODE": "1",
            "BMUX_SOCKET_PATH": socket, "BMUX_WORKSPACE_ID": workspace,
            "BMUX_SURFACE_ID": surface, "BMUX_AGENT_HOOK_STATE_DIR": root.path,
            "BMUX_CLI_SENTRY_DISABLED": "1", "BMUX_CLAUDE_HOOK_SENTRY_DISABLED": "1",
        ]
        let server = CLISocketFixture(path: socket, response: Self.responder(workspace: workspace, surface: surface))
        // Each original hook invocation requested five seconds. Timeout throws only after
        // the owned child has terminated and joined; capture then joins socket cleanup.
        let runner = ShellContractProcess(root: root, deadline: .seconds(5))
        let (outcome, phase) = try await server.capture {
            // Preserve producer failure while still draining its final queued requests.
            do {
                return Result<ShellContractProcess.Result, any Error>.success(try await runner.run(
                    executable: "/bin/sh", arguments: [
                        "-c", "exec \"$1\" hooks hermes-agent \"$2\" <\"$3\"",
                        "hermes-hook", cli, subcommand, inputURL.path,
                    ], environment: environment
                ))
            } catch { return .failure(error) }
        }
        let result: ShellContractProcess.Result
        do { result = try outcome.get() }
        catch {
            let output = Result { try String(contentsOf: root.appendingPathComponent("stdout"), encoding: .utf8) }
            let errors = Result { try String(contentsOf: root.appendingPathComponent("stderr"), encoding: .utf8) }
            Issue.record(error, "Hermes \(subcommand) failed after requests: \(phase); stdout: \(output); stderr: \(errors)")
            throw error
        }
        #expect(!FileManager.default.fileExists(atPath: socket))
        return (result, phase)
    }

    private static func responder(workspace: String, surface: String) -> @Sendable (String) throws -> String? {
        return { line in
            if !line.hasPrefix("{") {
                try #require(["set_agent_pid ", "clear_agent_pid ", "set_agent_lifecycle ", "set_status ",
                              "clear_status ", "notify_target_async ", "clear_notifications ", "log "]
                    .contains { line.hasPrefix($0) }, "Unexpected v1: \(line)")
                return "OK"
            }
            let request = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            let method = try #require(request["method"] as? String)
            if method == "feed.push", request["id"] == nil { return nil }
            let id = try #require(request["id"] as? String)
            let params = request["params"] as? [String: Any] ?? [:]
            let result: [String: Any]
            switch method {
            case "surface.list":
                #expect(params["workspace_id"] as? String == workspace)
                result = ["surfaces": [["id": surface, "ref": "surface:1", "index": 1, "focused": true]]]
            case "system.top": result = ["windows": []]
            case "debug.terminals": result = ["terminals": []]
            case "workspace.set_auto_title": result = ["enabled": false]
            case "surface.resume.set":
                #expect(params["workspace_id"] as? String == workspace)
                #expect(params["surface_id"] as? String == surface)
                result = [:]
            case "surface.resume.clear":
                #expect(params["surface_id"] as? String == surface)
                #expect(params["source"] as? String == "agent-hook")
                #expect(params["checkpoint_id"] as? String == "hermes-session-end-123")
                result = [:]
            case "feed.push": result = [:]
            default: throw NSError(domain: "Unexpected Hermes method: \(method)", code: 1)
            }
            return String(decoding: try JSONSerialization.data(withJSONObject: ["id": id, "ok": true, "result": result]), as: UTF8.self)
        }
    }
}
