import Foundation
import Testing

/// Owns one Grok session store and joins each hook before draining every socket connection.
final class GrokHookConnectionFixture {
    let root: URL
    let workspaceID = "11111111-1111-1111-1111-111111111111"
    let surfaceIDs = ["22222222-2222-2222-2222-222222222222", "33333333-3333-3333-3333-333333333333"]

    init() throws {
        root = URL(fileURLWithPath: "/tmp").appendingPathComponent("grok-hook-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    func run(_ action: String, session: String?, surface: String, fields: [String: Any] = [:], stallFeed: Bool = false) async throws -> [String] {
        let cli = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let socket = root.appendingPathComponent("socket").path
        let input = root.appendingPathComponent("input")
        let events = ["session-start": "SessionStart", "prompt-submit": "UserPromptSubmit", "notification": "Notification", "stop": "Stop"]
        var payload: [String: Any] = ["cwd": root.path, "hookEventName": try #require(events[action])]
        if let session { payload["sessionId"] = session }
        payload.merge(fields) { _, new in new }
        try JSONSerialization.data(withJSONObject: payload).write(to: input)
        let environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path, "PWD": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_SOCKET_PATH": socket,
            "BMUX_WORKSPACE_ID": workspaceID, "BMUX_SURFACE_ID": surface,
            "BMUX_AGENT_HOOK_STATE_DIR": root.path, "BMUX_CLI_SENTRY_DISABLED": "1",
            "GROK_HOME": root.appendingPathComponent("grok-home").path,
        ]
        let server = CLISocketFixture(path: socket, response: responder(surface: surface, stallFeed: stallFeed))
        let (result, commands) = try await server.capture {
            try await ShellContractProcess(root: root).run(executable: "/bin/sh", arguments: [
                "-c", "exec \"$1\" hooks grok \"$2\" <\"$3\"", "grok-hook", cli, action, input.path,
            ], environment: environment)
        }
        #expect(result.status == 0, "\(result.stderr); requests: \(commands)")
        #expect(result.stdout == "{}\n", "\(result.stderr)")
        return commands
    }

    func writeAssistantTranscript(session: String, text: String, cwd: String? = nil) throws {
        let directory = transcriptDirectory(session: session, cwd: cwd)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var data = try JSONSerialization.data(withJSONObject: ["type": "assistant", "content": text], options: [.sortedKeys])
        data.append(10)
        try data.write(to: directory.appendingPathComponent("chat_history.jsonl"))
    }

    func transcriptDirectory(session: String, cwd: String? = nil) -> URL {
        var encoded = ""
        for byte in (cwd ?? root.path).utf8 {
            let unreserved = (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte) || [45, 46, 95, 126].contains(byte)
            encoded += unreserved ? String(Character(UnicodeScalar(byte))) : String(format: "%%%02X", byte)
        }
        return root.appendingPathComponent("grok-home/sessions").appendingPathComponent(encoded).appendingPathComponent(session)
    }

    private func responder(surface: String, stallFeed: Bool) -> @Sendable (String) throws -> String? {
        let workspace = workspaceID, surfaces = surfaceIDs
        return { line in
            guard line.hasPrefix("{") else {
                try #require(["set_agent_pid ", "set_agent_lifecycle ", "clear_notifications ", "set_status ", "notify_target_async "]
                    .contains { line.hasPrefix($0) }, "Unexpected command: \(line)")
                return "OK"
            }
            let payload = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            let method = try #require(payload["method"] as? String)
            // Current telemetry is deliberately one-way; a missing ID is not malformed RPC.
            if method == "feed.push", payload["id"] == nil { return nil }
            let id = try #require(payload["id"] as? String)
            let params = payload["params"] as? [String: Any] ?? [:]
            let result: [String: Any]
            switch method {
            case "surface.list":
                #expect(params["workspace_id"] as? String == workspace)
                result = ["surfaces": surfaces.enumerated().map { index, candidate in
                    ["id": candidate, "ref": "surface:\(index + 1)", "focused": candidate == surface] as [String: Any]
                }]
            case "system.top": result = ["windows": []]
            case "surface.resume.set":
                #expect(params["workspace_id"] as? String == workspace)
                #expect(params["surface_id"] as? String == surface)
                result = [:]
            case "workspace.set_auto_title": result = ["applied": false]
            case "feed.push":
                if stallFeed { return nil }
                result = [:]
            default: throw NSError(domain: "Unexpected Grok fixture method: \(method)", code: 1)
            }
            return String(decoding: try JSONSerialization.data(withJSONObject: ["id": id, "ok": true, "result": result]), as: UTF8.self)
        }
    }
}
