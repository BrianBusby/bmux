import BmuxFoundation
import Foundation
import Testing

/// Owns the CLI process and socket protocol for creating one SSH workspace.
final class SSHWorkspaceCreationFixture {
    let root: URL
    let workspaceID = "11111111-1111-1111-1111-111111111111"
    let windowID = "22222222-2222-2222-2222-222222222222"
    let surfaceID = "33333333-3333-3333-3333-333333333333"
    var socketPath: String { root.appendingPathComponent("socket").path }

    init() throws {
        root = URL(fileURLWithPath: "/tmp").appendingPathComponent("ssh-create-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    func run(cli: String, includesSurface: Bool) async throws -> [[String: Any]] {
        let stdout = root.appendingPathComponent("stdout"), stderr = root.appendingPathComponent("stderr")
        let runner = CommandRunner(environment: [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_SOCKET_PATH": socketPath,
            "BMUX_CLI_SENTRY_DISABLED": "1", "BMUX_CLAUDE_HOOK_SENTRY_DISABLED": "1",
        ])
        let server = CLISocketFixture(path: socketPath, response: responder(includesSurface: includesSurface))
        let (result, commands) = try await server.capture {
            await runner.run(directory: root.path, executable: "/bin/sh", arguments: [
                "-c", "program=$1; output=$2; errors=$3; shift 3; exec \"$program\" \"$@\" </dev/null >\"$output\" 2>\"$errors\"",
                "ssh-create", cli, stdout.path, stderr.path,
                "ssh", "--name", "SSH Workspace", "--port", "2222",
                "--identity", "/Users/test/.ssh/id_ed25519",
                "--ssh-option", "ControlPath /tmp/bmux-ssh-%C",
                "--ssh-option", "StrictHostKeyChecking=accept-new",
                "--window", windowID, "bmux-macmini",
            ], timeout: 5)
        }
        try #require(!result.timedOut)
        try #require(result.executionError == nil)
        let errors = try String(contentsOf: stderr, encoding: .utf8)
        #expect(result.exitStatus == 0, "\(errors)")
        #expect(errors.isEmpty, "\(errors)")
        #expect(try String(contentsOf: stdout, encoding: .utf8) == "OK workspace=workspace:7 target=bmux-macmini state=disconnected\n")
        return try commands.map {
            try #require(JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any])
        }
    }

    private func responder(includesSurface: Bool) -> @Sendable (String) throws -> String? {
        let workspace = workspaceID, window = windowID, surface = surfaceID
        return { line in
            let request = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            let id = try #require(request["id"] as? String)
            let method = try #require(request["method"] as? String)
            let params = try #require(request["params"] as? [String: Any])
            var result: [String: Any]
            switch method {
            case "workspace.create":
                result = ["workspace_id": workspace, "window_id": window]
                if includesSurface { result["surface_id"] = surface }
            case "surface.list":
                #expect(!includesSurface)
                #expect(params["workspace_id"] as? String == workspace)
                result = ["surfaces": [["id": surface, "ref": "surface:1", "focused": true]]]
            case "workspace.rename", "workspace.select": result = ["workspace_id": workspace]
            case "workspace.remote.configure":
                let autoConnect = try #require(params["auto_connect"] as? Bool)
                result = ["workspace_id": workspace, "workspace_ref": "workspace:7",
                          "remote": ["enabled": true, "state": autoConnect ? "connecting" : "disconnected"]]
            default:
                Issue.record("Unexpected SSH creation method: \(method)")
                return String(decoding: try JSONSerialization.data(withJSONObject:
                    ["id": id, "ok": false, "error": ["code": "unexpected", "message": method]]), as: UTF8.self)
            }
            return String(decoding: try JSONSerialization.data(withJSONObject:
                ["id": id, "ok": true, "result": result]), as: UTF8.self)
        }
    }
}
