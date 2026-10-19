import BmuxFoundation
import Foundation
import Testing

/// Owns the protocol and persisted state for one replaced-session cleanup.
final class ClaudeSessionEndFixture {
    let root: URL
    let workspaceID = "33333333-3333-3333-3333-333333333333"
    let surfaceID = "22222222-2222-2222-2222-222222222222"
    let callerWorkspaceID = "11111111-1111-1111-1111-111111111111"
    var stateURL: URL { root.appendingPathComponent("claude-hook-sessions.json") }

    init(perSurfaceState: Bool) throws {
        root = URL(fileURLWithPath: "/tmp").appendingPathComponent("claude-end-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let now = Date().timeIntervalSince1970
        func record(_ session: String, updated: Double) -> [String: Any] {
            ["sessionId": session, "workspaceId": workspaceID, "surfaceId": surfaceID,
             "cwd": root.path, "startedAt": now - 10, "updatedAt": updated]
        }
        let active: [String: Any] = ["sessionId": "active-session", "updatedAt": now]
        // A late hook can update the old record after replacement. The explicit
        // active boundary, not timestamp recency, controls visible cleanup.
        var state: [String: Any] = [
            "version": 1,
            "sessions": ["stale-session": record("stale-session", updated: now),
                         "active-session": record("active-session", updated: now - 1)],
            "activeSessionsByWorkspace": [workspaceID: active],
        ]
        if perSurfaceState { state["activeSessionsBySurface"] = [surfaceID: active] }
        do { try JSONSerialization.data(withJSONObject: state).write(to: stateURL) }
        catch { try? FileManager.default.removeItem(at: root); throw error }
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    func run(cli: String, explicitSession: Bool) async throws -> [String] {
        var payload = ["cwd": root.path, "hook_event_name": "SessionEnd"]
        if explicitSession { payload["session_id"] = "stale-session" }
        let input = root.appendingPathComponent("input")
        try JSONSerialization.data(withJSONObject: payload).write(to: input)
        let stdout = root.appendingPathComponent("stdout"), stderr = root.appendingPathComponent("stderr")
        let socket = root.appendingPathComponent("socket").path
        let runner = CommandRunner(environment: [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_SOCKET_PATH": socket,
            "BMUX_WORKSPACE_ID": callerWorkspaceID, "BMUX_SURFACE_ID": surfaceID,
            "BMUX_CLAUDE_HOOK_STATE_PATH": stateURL.path,
            "BMUX_CLI_SENTRY_DISABLED": "1", "BMUX_CLAUDE_HOOK_SENTRY_DISABLED": "1",
        ])
        let server = CLISocketFixture(path: socket, response: responder())
        let (result, commands) = try await server.capture {
            await runner.run(directory: root.path, executable: "/bin/sh", arguments: [
                "-c", "exec \"$1\" hooks claude session-end <\"$2\" >\"$3\" 2>\"$4\"",
                "claude-end", cli, input.path, stdout.path, stderr.path,
            ], timeout: CLIProcessTestTimeout().seconds(5))
        }
        try #require(!result.timedOut)
        try #require(result.executionError == nil)
        let errors = try String(contentsOf: stderr, encoding: .utf8)
        #expect(result.exitStatus == 0, "\(errors)")
        #expect(try String(contentsOf: stdout, encoding: .utf8) == "OK\n")
        return commands
    }

    private func responder() -> @Sendable (String) throws -> String? {
        let surface = surfaceID, workspace = workspaceID, caller = callerWorkspaceID
        return { line in
            guard line.hasPrefix("{") else {
                try #require(["clear_agent_pid ", "clear_status ", "clear_notifications "].contains { line.hasPrefix($0) })
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
                let requested = params["workspace_id"] as? String
                try #require(requested == workspace || requested == caller)
                result = ["surfaces": [["id": surface, "ref": "surface:1", "focused": true]]]
            case "surface.resume.clear":
                #expect(params["surface_id"] as? String == surface)
                #expect(params["checkpoint_id"] as? String == "stale-session")
                result = ["cleared": true]
            case "feed.push": result = [:]
            default: throw NSError(domain: "Unexpected Claude cleanup method: \(method)", code: 1)
            }
            return String(decoding: try JSONSerialization.data(withJSONObject: ["id": id, "ok": true, "result": result]), as: UTF8.self)
        }
    }
}
