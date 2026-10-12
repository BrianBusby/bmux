import BmuxFoundation
import Foundation
import Testing

/// Owns one hook invocation's isolated socket, persisted session and process I/O.
final class CodexRejectedAmbientFixture {
    enum Identity: Sendable { case invalidSurface, foreignMapping, validAmbient, workspaceMapping }
    enum Binding: Sendable { case missing, pid, tty, unlistedPID }

    let root: URL
    let identity: Identity
    let workspaceID = "33333333-3333-3333-3333-333333333333"
    let focusedSurfaceID = "44444444-4444-4444-4444-444444444444"
    let liveSurfaceID = "55555555-5555-5555-5555-555555555555"
    let foreignWorkspaceID = "11111111-1111-1111-1111-111111111111"
    let invalidSurfaceID = "22222222-2222-2222-2222-222222222222"
    let sessionID = "routing-session"

    init(identity: Identity) throws {
        self.identity = identity
        root = URL(fileURLWithPath: "/tmp").appendingPathComponent("codex-route-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if identity == .foreignMapping || identity == .workspaceMapping {
            let now = Date().timeIntervalSince1970
            let store: [String: Any] = ["version": 1, "sessions": [sessionID: [
                "sessionId": sessionID, "workspaceId": workspaceID, "surfaceId": focusedSurfaceID,
                "cwd": root.path, "startedAt": now, "updatedAt": now,
            ]]]
            try JSONSerialization.data(withJSONObject: store).write(to: stateURL)
        }
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    private var stateURL: URL { root.appendingPathComponent("codex-hook-sessions.json") }

    func storedSession() throws -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: stateURL.path) else { return nil }
        let data = try Data(contentsOf: stateURL)
        let state = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let sessions = try #require(state["sessions"] as? [String: Any])
        return sessions[sessionID] as? [String: Any]
    }

    func run(cli: String, binding: Binding, explicit: Bool = false) async throws -> [String] {
        let input = root.appendingPathComponent("input")
        try JSONSerialization.data(withJSONObject: [
            "session_id": sessionID, "cwd": root.path,
            "hook_event_name": "UserPromptSubmit", "prompt": "continue",
        ]).write(to: input)
        let stdout = root.appendingPathComponent("stdout"), stderr = root.appendingPathComponent("stderr")
        let socketPath = root.appendingPathComponent("socket").path
        let pid = ProcessInfo.processInfo.processIdentifier
        var environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "BMUX_SOCKET_PATH": socketPath, "BMUX_AGENT_HOOK_STATE_DIR": root.path,
            "BMUX_CLI_SENTRY_DISABLED": "1", "CODEX_HOME": root.appendingPathComponent("codex-home").path,
            "BMUX_CODEX_PID": String(pid),
            "BMUX_WORKSPACE_ID": identity == .foreignMapping ? foreignWorkspaceID : workspaceID,
        ]
        if identity != .workspaceMapping {
            environment["BMUX_SURFACE_ID"] = identity == .validAmbient ? liveSurfaceID : invalidSurfaceID
        }
        if binding == .tty { environment["BMUX_CLI_TTY_NAME"] = "routing-probe" }
        var arguments = ["hooks", "codex", "prompt-submit"]
        if explicit {
            arguments += ["--workspace", try #require(environment["BMUX_WORKSPACE_ID"]),
                          "--surface", try #require(environment["BMUX_SURFACE_ID"])]
        }
        let server = CLISocketFixture(path: socketPath, response: responder(binding: binding, pid: pid))
        let runner = CommandRunner(environment: environment)
        let (result, commands) = try await server.capture {
            // Owned files leave the cooperative executor available for socket servicing.
            await runner.run(directory: root.path, executable: "/bin/sh", arguments: [
                "-c", "cli=$1; input=$2; output=$3; errors=$4; shift 4; exec \"$cli\" \"$@\" < \"$input\" > \"$output\" 2> \"$errors\"",
                "codex-routing", cli, input.path, stdout.path, stderr.path,
            ] + arguments, timeout: 5)
        }
        try #require(!result.timedOut)
        try #require(result.executionError == nil)
        let errorText = try String(contentsOf: stderr, encoding: .utf8)
        #expect(result.exitStatus == 0, "\(errorText)")
        #expect(try String(contentsOf: stdout, encoding: .utf8) == "{}\n")
        return commands
    }

    private func responder(binding: Binding, pid: Int32) -> @Sendable (String) throws -> String? {
        let workspace = workspaceID, focused = focusedSurfaceID, live = liveSurfaceID, invalid = invalidSurfaceID
        return { line in
            guard line.hasPrefix("{") else {
                try #require(["set_agent_pid ", "set_agent_lifecycle ", "clear_notifications ", "set_status ", "notify_target"].contains { line.hasPrefix($0) }, "Unexpected command: \(line)")
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
            case "surface.list":
                if params["workspace_id"] as? String == workspace {
                    result = ["surfaces": [["id": focused, "ref": "surface:1", "focused": true],
                                           ["id": live, "ref": "surface:2", "focused": false]]]
                } else { error = ["code": "not_found", "message": "workspace not found"] }
            case "system.top":
                let surface: [String: Any] = ["id": binding == .pid ? live : invalid, "top_level_pids": [pid]]
                let window: [String: Any] = ["workspaces": [["id": workspace, "panes": [["surfaces": [surface]]]]]]
                result = ["windows": binding == .pid || binding == .unlistedPID ? [window] : []]
            case "debug.terminals":
                result = ["terminals": binding == .tty
                    ? [["tty": "routing-probe", "workspace_id": workspace, "surface_id": live]] : []]
            case "workspace.current": result = ["workspace_id": workspace]
            case "workspace.list": result = ["workspaces": [["id": workspace, "selected": true]]]
            case "workspace.set_auto_title":
                try #require(params["probe"] as? Bool == true, "Unexpected title mutation: \(line)")
                result = ["applied": false]
            case "surface.resume.set", "feed.push": break
            default: Issue.record("Unexpected method: \(method)"); error = ["code": "unexpected_method", "message": method]
            }
            var response: [String: Any] = ["id": id, "ok": error == nil]
            if let error { response["error"] = error } else { response["result"] = result }
            return String(decoding: try JSONSerialization.data(withJSONObject: response), as: UTF8.self)
        }
    }
}
