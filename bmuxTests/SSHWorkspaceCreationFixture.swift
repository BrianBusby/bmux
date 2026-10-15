import Foundation
import Testing

/// Owns the CLI process and socket protocol for creating one SSH workspace.
final class SSHWorkspaceCreationFixture: Sendable {
    let root: URL
    let workspaceID = "11111111-1111-1111-1111-111111111111"
    let windowID = "22222222-2222-2222-2222-222222222222"
    let surfaceID = "33333333-3333-3333-3333-333333333333"
    var socketPath: String { root.appendingPathComponent("socket").path }

    init() throws {
        root = URL(fileURLWithPath: "/tmp").appendingPathComponent("ssh-create-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        do { try FileManager.default.removeItem(at: root) }
        catch { Issue.record(error, "Could not remove owned SSH workspace fixture directory") }
    }

    func run(cli: String, includesSurface: Bool) async throws -> [[String: Any]] {
        let password = "owned-ssh-creation"
        let environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path, "XDG_CONFIG_HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_SOCKET_PATH": socketPath,
            "BMUX_CLI_SENTRY_DISABLED": "1", "BMUX_CLAUDE_HOOK_SENTRY_DISABLED": "1",
        ]
        let server = CLISocketFixture(path: socketPath,
            response: responder(includesSurface: includesSurface, password: password))
        let (outcome, commands) = try await server.capture {
            // Preserve failure until the producer is joined and the socket has drained.
            do {
                return Result<ShellContractProcess.Result, any Error>.success(try await ShellContractProcess(
                    root: root, deadline: .seconds(CLIProcessTestTimeout().seconds(5))
                ).run(executable: cli, arguments: [
                    "--password", password, "ssh", "--name", "SSH Workspace", "--port", "2222",
                    "--identity", "/Users/test/.ssh/id_ed25519",
                    "--ssh-option", "ControlPath /tmp/bmux-ssh-%C",
                    "--ssh-option", "StrictHostKeyChecking=accept-new",
                    "--window", windowID, "bmux-macmini",
                ], environment: environment))
            } catch { return .failure(error) }
        }
        let result: ShellContractProcess.Result
        do { result = try outcome.get() }
        catch {
            let output = Result { try String(contentsOf: root.appendingPathComponent("stdout"), encoding: .utf8) }
            let errors = Result { try String(contentsOf: root.appendingPathComponent("stderr"), encoding: .utf8) }
            Issue.record(error, "SSH creation failed after joined capture; stdout: \(output); stderr: \(errors)")
            throw error
        }
        #expect(result.status == 0, "\(result.stderr)")
        #expect(result.stderr.isEmpty, "\(result.stderr)")
        #expect(result.stdout == "OK workspace=workspace:7 target=bmux-macmini state=disconnected\n")
        #expect(commands.first == "auth \(password)")
        return try commands.dropFirst().map {
            try #require(JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any])
        }
    }

    private func responder(includesSurface: Bool, password: String) -> @Sendable (String) throws -> String? {
        let workspace = workspaceID, window = windowID, surface = surfaceID
        return { line in
            if line == "auth \(password)" { return "OK" }
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
