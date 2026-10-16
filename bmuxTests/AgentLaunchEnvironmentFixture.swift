import Foundation
import Testing

/// Owns one session-start process, protocol endpoint and persisted launch record.
final class AgentLaunchEnvironmentFixture {
    let root: URL
    let workspaceID = "11111111-1111-1111-1111-111111111111"
    let surfaceID = "22222222-2222-2222-2222-222222222222"

    init() throws {
        root = URL(fileURLWithPath: "/tmp").appendingPathComponent("launch-env-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        do { try FileManager.default.removeItem(at: root) }
        catch { Issue.record(error, "Could not remove owned agent launch fixture directory") }
    }

    func run(cli: String, codexHome: String) async throws -> [String: Any] {
        let socket = root.appendingPathComponent("socket").path
        let argv = ["/usr/local/bin/codex", "--model", "gpt-5.4", "old prompt"]
        let environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path,
            "PATH": "/tmp/custom-bin:/usr/bin", "SHELL": "/bin/zsh",
            "BMUX_SOCKET_PATH": socket, "BMUX_WORKSPACE_ID": workspaceID,
            "BMUX_SURFACE_ID": surfaceID, "BMUX_AGENT_HOOK_STATE_DIR": root.path,
            "BMUX_AGENT_LAUNCH_KIND": "codex",
            "BMUX_AGENT_LAUNCH_EXECUTABLE": argv[0],
            "BMUX_AGENT_LAUNCH_ARGV_B64": Data((argv.joined(separator: "\0") + "\0").utf8).base64EncodedString(),
            "BMUX_AGENT_LAUNCH_CWD": "/tmp/repo", "CODEX_HOME": codexHome,
            "BMUX_CLI_SENTRY_DISABLED": "1",
        ]
        let runner = ShellContractProcess(root: root, deadline: .seconds(CLIProcessTestTimeout().seconds(5)), terminationGrace: .milliseconds(200))
        let server = CLISocketFixture(path: socket, response: responder())
        let (outcome, commands) = try await server.capture {
            // Even failures complete the owned producer before the socket's final drain.
            do {
                return Result<ShellContractProcess.Result, any Error>.success(try await runner.run(
                    executable: cli, arguments: ["hooks", "codex", "session-start"], environment: environment
                ))
            } catch { return .failure(error) }
        }
        let result: ShellContractProcess.Result
        do { result = try outcome.get() }
        catch {
            let output = Result { try String(contentsOf: root.appendingPathComponent("stdout"), encoding: .utf8) }
            let errors = Result { try String(contentsOf: root.appendingPathComponent("stderr"), encoding: .utf8) }
            Issue.record(error, "Session-start failed after requests: \(commands); stdout: \(output); stderr: \(errors)")
            throw error
        }
        #expect(result.status == 0, "\(result.stderr)")
        #expect(result.stdout == "{}\n")
        let state = try #require(JSONSerialization.jsonObject(with:
            Data(contentsOf: root.appendingPathComponent("codex-hook-sessions.json"))) as? [String: Any])
        let sessions = try #require(state["sessions"] as? [String: [String: Any]])
        let session = try #require(sessions[surfaceID])
        #expect(session["workspaceId"] as? String == workspaceID)
        #expect(session["surfaceId"] as? String == surfaceID)
        return try #require(session["launchCommand"] as? [String: Any])
    }

    private func responder() -> @Sendable (String) throws -> String? {
        let workspace = workspaceID, surface = surfaceID
        return { line in
            guard line.hasPrefix("{") else {
                try #require(["set_agent_pid ", "set_agent_lifecycle "].contains { line.hasPrefix($0) })
                #expect(line.contains("--tab=\(workspace)") && line.contains("--panel=\(surface)"))
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
                result = ["surfaces": [["id": surface, "ref": "surface:1", "focused": true]]]
            case "system.top": result = ["windows": []]
            case "workspace.list": result = ["workspaces": [["id": workspace, "selected": true]]]
            case "surface.resume.set":
                #expect(params["workspace_id"] as? String == workspace)
                #expect(params["surface_id"] as? String == surface)
                result = [:]
            default: throw NSError(domain: "Unexpected launch capture method: \(method)", code: 1)
            }
            return String(decoding: try JSONSerialization.data(withJSONObject:
                ["id": id, "ok": true, "result": result]), as: UTF8.self)
        }
    }
}
