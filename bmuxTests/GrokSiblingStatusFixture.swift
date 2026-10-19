import Foundation
import Testing

/// Owns two saved Grok routes while the running surface remains focused throughout completion.
final class GrokSiblingStatusFixture {
    let root: URL
    let workspace = "11111111-1111-1111-1111-111111111111"
    let runningSurface = "22222222-2222-2222-2222-222222222222"
    let completingSurface = "33333333-3333-3333-3333-333333333333"

    init() throws {
        root = URL(fileURLWithPath: "/tmp/grok-sibling-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        do { try FileManager.default.removeItem(at: root) }
        catch { Issue.record(error, "Could not remove owned Grok sibling fixture directory") }
    }

    /// Only starts supply ambient IDs; later actions must resolve the independently saved session route.
    func run(_ action: String, session: String, ambientSurface: String? = nil, fields: [String: String] = [:]) async throws -> [String] {
        let cli = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let socket = root.appendingPathComponent("socket").path
        let input = root.appendingPathComponent("input")
        let password = "grok-sibling-owned-password"
        let events = ["session-start": "SessionStart", "stop": "Stop", "prompt-submit": "UserPromptSubmit", "notification": "Notification"]
        var payload = ["sessionId": session, "cwd": root.path, "hookEventName": try #require(events[action])]
        payload.merge(fields) { _, new in new }
        try JSONSerialization.data(withJSONObject: payload).write(to: input)
        var environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path, "PWD": root.path,
            "XDG_CONFIG_HOME": root.path, "XDG_STATE_HOME": root.path, "TMPDIR": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "GROK_HOME": root.appendingPathComponent("grok-home").path,
            "BMUX_SOCKET_PATH": socket, "BMUX_SOCKET_PASSWORD": password,
            "BMUX_AGENT_HOOK_STATE_DIR": root.path, "BMUX_CLI_SENTRY_DISABLED": "1",
        ]
        if let ambientSurface {
            environment["BMUX_WORKSPACE_ID"] = workspace
            environment["BMUX_SURFACE_ID"] = ambientSurface
        }
        let server = CLISocketFixture(path: socket, response: responder(password: password))
        let (outcome, commands) = try await server.capture {
            // Failure also joins the producer before the server drains already queued input.
            do {
                return Result<ShellContractProcess.Result, any Error>.success(try await ShellContractProcess(
                    root: root, deadline: .seconds(CLIProcessTestTimeout().seconds(5))
                ).run(executable: "/bin/sh", arguments: [
                    "-c", "exec \"$1\" hooks grok \"$2\" <\"$3\"", "grok-sibling", cli, action, input.path,
                ], environment: environment))
            } catch { return .failure(error) }
        }
        let output: ShellContractProcess.Result
        do { output = try outcome.get() }
        catch {
            Issue.record(error, "Grok \(action) failed after \(commands.count) captured requests")
            throw error
        }
        #expect(output.status == 0, "\(output.stderr)")
        #expect(output.stdout == "{}\n", "\(output.stderr)")
        return commands
    }

    private func responder(password: String) -> @Sendable (String) throws -> String? {
        let running = runningSurface, completing = completingSurface
        return { line in
            if line.hasPrefix("auth ") {
                guard line == "auth \(password)" else { throw NSError(domain: "GrokSiblingAuthenticationMismatch", code: 1) }
                return "OK"
            }
            guard line.hasPrefix("{") else { return "OK" }
            let request = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            let method = try #require(request["method"] as? String)
            // Feed uses a separate connection and deliberately has no response or request ID.
            if method == "feed.push", request["id"] == nil { return nil }
            let id = try #require(request["id"] as? String)
            var response: [String: Any] = ["id": id, "ok": method == "surface.list" || method == "feed.push"]
            switch method {
            case "surface.list":
                response["result"] = ["surfaces": [
                    ["id": running, "ref": "surface:1", "focused": true],
                    ["id": completing, "ref": "surface:2", "focused": false],
                ]]
            case "feed.push": response["result"] = [:] as [String: String]
            default:
                response["error"] = ["code": "unrecognized_method", "message": "unexpected method: \(method)"]
            }
            return String(decoding: try JSONSerialization.data(withJSONObject: response), as: UTF8.self)
        }
    }
}
