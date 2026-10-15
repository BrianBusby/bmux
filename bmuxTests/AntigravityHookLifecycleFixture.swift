import Foundation
import Testing

/// Owns the hook store and joins each producer before collecting RPC and one-way telemetry.
final class AntigravityHookLifecycleFixture {
    let root: URL
    let workspaceID = "11111111-1111-1111-1111-111111111111"
    let surfaceID = "22222222-2222-2222-2222-222222222222"

    init() throws {
        root = URL(fileURLWithPath: "/tmp").appendingPathComponent("antigravity-hook-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    func run(_ action: String, input: String) async throws -> [String] {
        let cli = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let socket = root.appendingPathComponent("socket").path
        let inputURL = root.appendingPathComponent("input")
        try input.write(to: inputURL, atomically: true, encoding: .utf8)
        let environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path, "PWD": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_SOCKET_PATH": socket,
            "BMUX_WORKSPACE_ID": workspaceID, "BMUX_SURFACE_ID": surfaceID,
            "BMUX_AGENT_HOOK_STATE_DIR": root.path, "BMUX_CLI_SENTRY_DISABLED": "1",
        ]
        let workspace = workspaceID, surface = surfaceID
        let server = CLISocketFixture(path: socket) { line in
            guard line.hasPrefix("{") else {
                try #require(["set_agent_pid ", "clear_agent_pid ", "set_agent_lifecycle ", "clear_notifications ", "set_status ", "notify_target_async "]
                    .contains { line.hasPrefix($0) }, "Unexpected command: \(line)")
                return "OK"
            }
            let payload = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            let method = try #require(payload["method"] as? String)
            if method == "feed.push", payload["id"] == nil { return nil }
            let id = try #require(payload["id"] as? String)
            let result: [String: Any]
            switch method {
            case "surface.list":
                let params = try #require(payload["params"] as? [String: Any])
                #expect(params["workspace_id"] as? String == workspace)
                result = ["surfaces": [["id": surface, "ref": "surface:1", "focused": true]]]
            case "system.top": result = ["windows": []]
            case "surface.resume.set":
                let params = try #require(payload["params"] as? [String: Any])
                #expect(params["workspace_id"] as? String == workspace)
                #expect(params["surface_id"] as? String == surface)
                result = [:]
            case "workspace.set_auto_title": result = ["applied": false]
            case "feed.push": result = [:]
            default: throw NSError(domain: "Unexpected Antigravity fixture method: \(method)", code: 1)
            }
            return String(decoding: try JSONSerialization.data(withJSONObject: ["id": id, "ok": true, "result": result]), as: UTF8.self)
        }
        let (result, commands) = try await server.capture {
            try await ShellContractProcess(root: root, deadline: .seconds(CLIProcessTestTimeout().seconds(5))).run(executable: "/bin/sh", arguments: [
                "-c", "exec \"$1\" hooks antigravity \"$2\" <\"$3\"", "antigravity-hook", cli, action, inputURL.path,
            ], environment: environment)
        }
        #expect(result.status == 0, "\(result.stderr); requests: \(commands)")
        #expect(result.stdout == "{}\n", "\(result.stderr)")
        return commands
    }
}
