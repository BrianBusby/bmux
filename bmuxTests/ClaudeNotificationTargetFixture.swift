import BmuxFoundation
import Foundation
import Testing

/// Owns one notification hook's socket, session state and process I/O.
final class ClaudeNotificationTargetFixture {
    enum Routing: Sendable { case staleSession, explicitWorkspaceRef, callerEnvironment }

    let root: URL
    let routing: Routing
    let agentPID: Int?
    let targetWorkspaceID = "22222222-2222-2222-2222-222222222222"
    let targetSurfaceID = "33333333-3333-3333-3333-333333333333"
    let staleWorkspaceID = "11111111-1111-1111-1111-111111111111"
    let focusedWorkspaceID = "99999999-9999-9999-9999-999999999999"

    init(routing: Routing, agentPID: Int? = nil) throws {
        self.routing = routing
        self.agentPID = agentPID
        root = URL(fileURLWithPath: "/tmp").appendingPathComponent("claude-target-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    func run(cli: String, permission: Bool) async throws -> [String] {
        let stateURL = root.appendingPathComponent("claude-hook-sessions.json")
        if routing == .staleSession {
            let now = Date().timeIntervalSince1970
            let store: [String: Any] = ["version": 1, "sessions": ["resumed-session": [
                "sessionId": "resumed-session", "workspaceId": staleWorkspaceID,
                "surfaceId": "44444444-4444-4444-4444-444444444444", "cwd": root.path,
                "startedAt": now, "updatedAt": now,
            ]]]
            try JSONSerialization.data(withJSONObject: store).write(to: stateURL)
        }
        let input = root.appendingPathComponent("input")
        var payload = ["session_id": routing == .staleSession ? "resumed-session" : "explicit-ref",
                       "hook_event_name": "Notification", "message": "Claude needs your input"]
        if permission {
            payload["notification_type"] = "permission_prompt"
            payload["message"] = "Please approve this command"
        }
        try JSONSerialization.data(withJSONObject: payload).write(to: input)
        let stdout = root.appendingPathComponent("stdout")
        let stderr = root.appendingPathComponent("stderr")
        let socketPath = root.appendingPathComponent("socket").path
        var environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_SOCKET_PATH": socketPath,
            "BMUX_CLAUDE_HOOK_STATE_PATH": stateURL.path,
            "BMUX_CLI_SENTRY_DISABLED": "1", "BMUX_CLAUDE_HOOK_SENTRY_DISABLED": "1",
        ]
        if let agentPID { environment["BMUX_CLAUDE_PID"] = String(agentPID) }
        var arguments = ["hooks", "claude", "notification"]
        if routing != .explicitWorkspaceRef {
            environment["BMUX_WORKSPACE_ID"] = targetWorkspaceID
            environment["BMUX_SURFACE_ID"] = targetSurfaceID
        } else {
            arguments += ["--workspace", "workspace:1"]
        }
        let server = CLISocketFixture(path: socketPath, response: responder())
        let runner = CommandRunner(environment: environment)
        let (result, commands) = try await server.capture {
            // Owned files avoid blocking cooperative pipe readers while socket tasks run.
            await runner.run(directory: root.path, executable: "/bin/sh", arguments: [
                "-c", "cli=$1; input=$2; output=$3; errors=$4; shift 4; exec \"$cli\" \"$@\" < \"$input\" > \"$output\" 2> \"$errors\"",
                "claude-notification", cli, input.path, stdout.path, stderr.path,
            ] + arguments, timeout: 5)
        }
        try #require(!result.timedOut)
        try #require(result.executionError == nil)
        let errorText = try String(contentsOf: stderr, encoding: .utf8)
        #expect(result.exitStatus == 0, "\(errorText)")
        #expect(try String(contentsOf: stdout, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) == "OK")
        return commands
    }

    private func responder() -> @Sendable (String) throws -> String? {
        let target = targetWorkspaceID, surface = targetSurfaceID, focused = focusedWorkspaceID
        let window = staleWorkspaceID
        return { line in
            guard line.hasPrefix("{") else {
                try #require(["set_agent_lifecycle ", "set_status ", "notify_target_async "].contains { line.hasPrefix($0) }, "Unexpected command: \(line)")
                return "OK"
            }
            let payload = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            let method = try #require(payload["method"] as? String)
            if method == "feed.push", payload["id"] == nil { return nil }
            let id = try #require(payload["id"] as? String, "\(line)")
            let params = payload["params"] as? [String: Any] ?? [:]
            var result: [String: Any] = [:]
            var error: [String: String]?
            switch method {
            case "window.list": result = ["windows": [["id": window]]]
            case "workspace.list":
                try #require(params["window_id"] as? String == window)
                result = ["workspaces": [["id": target, "ref": "workspace:1"]]]
            case "surface.list":
                let workspace = params["workspace_id"] as? String
                if workspace == target || workspace == focused {
                    result = ["surfaces": [["id": workspace == target ? surface : "88888888-8888-8888-8888-888888888888",
                                             "ref": "surface:1", "index": 1, "focused": true]]]
                } else {
                    error = ["code": "not_found", "message": "workspace not found"]
                }
            // No live process inventory: PID remains metadata, and caller IDs resolve the target.
            case "system.top": result = ["windows": []]
            case "debug.terminals": result = ["terminals": []]
            case "workspace.current": result = ["workspace_id": focused]
            case "feed.push": break
            default: Issue.record("Unexpected method: \(method)"); error = ["code": "unexpected_method", "message": method]
            }
            var response: [String: Any] = ["id": id, "ok": error == nil]
            if let error { response["error"] = error } else { response["result"] = result }
            return String(decoding: try JSONSerialization.data(withJSONObject: response), as: UTF8.self)
        }
    }
}
