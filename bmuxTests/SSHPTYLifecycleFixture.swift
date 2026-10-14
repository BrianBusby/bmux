import BmuxFoundation
import Foundation
import Testing

/// Runs the real CLI against owned RPC and bridge transports with exact lifecycle payloads.
final class SSHPTYLifecycleFixture {
    enum Scenario: CaseIterable, Sendable { case running, gone, withoutSurface, reset }
    let root: URL
    let workspace = "22222222-2222-2222-2222-222222222222"
    let surface = "33333333-3333-3333-3333-333333333333"

    init() throws {
        root = URL(fileURLWithPath: "/tmp").appendingPathComponent("pty-life-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    deinit { try? FileManager.default.removeItem(at: root) }

    func run(cli: String, scenario: Scenario, terminal: Bool, waitsForResize: Bool) async throws {
        let workspace = workspace, surface = surface
        let hasSurface = scenario != .withoutSurface
        let session = hasSurface ? "ssh-\(workspace)-\(surface)" : "ssh-manual-session"
        let columns = terminal ? 132 : 80, rows = terminal ? 43 : 24
        let socketPath = root.appendingPathComponent("socket").path
        let stderr = root.appendingPathComponent("stderr")
        let output = try CLIOutputChannel(root: root, terminal: terminal)
        let environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "BMUX_SOCKET_PATH": socketPath, "BMUX_CLI_SENTRY_DISABLED": "1",
        ]
        var arguments = ["ssh-pty-attach", "--workspace", workspace, "--session-id", session]
        if hasSurface { arguments += ["--attachment-id", surface] }
        if scenario == .running { arguments += ["--require-existing"] }
        let (responses, responseWritten) = AsyncStream<String>.makeStream()
        let bridge = SSHPTYLifecycleBridge(waitsForResize: waitsForResize, resets: scenario == .reset)
        let captured = try await bridge.capture(responses: responses) { port in
            let server = CLISocketFixture(path: socketPath, responseWritten: responseWritten) { line in
                let request = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
                let id = try #require(request["id"] as? String)
                let method = try #require(request["method"] as? String)
                let params = try #require(request["params"] as? [String: Any])
                var expected: [String: Any] = ["workspace_id": workspace]
                var result: [String: Any] = [:]
                switch method {
                case "workspace.remote.pty_bridge", "workspace.remote.pty_resize":
                    let attachment = try #require(params["attachment_id"] as? String)
                    if hasSurface { try #require(attachment == surface) }
                    else { try #require(UUID(uuidString: attachment) != nil) }
                    expected["session_id"] = session; expected["attachment_id"] = attachment
                    if hasSurface { expected["surface_id"] = surface; expected["allow_moved_surface"] = true }
                    if method == "workspace.remote.pty_bridge" {
                        expected["command"] = ""; expected["require_existing"] = scenario == .running
                        result = ["host": "127.0.0.1", "port": port, "token": "bridge-token",
                                  "session_id": session, "attachment_id": attachment]
                    } else {
                        expected["attachment_token"] = "attach-token"
                        expected["cols"] = columns; expected["rows"] = rows
                        result = ["resized": true]
                    }
                case "workspace.remote.pty_sessions":
                    if hasSurface {
                        expected["surface_id"] = surface; expected["session_id"] = session
                        expected["allow_moved_surface"] = true
                    }
                    result = ["sessions": scenario == .running ? [["workspace_id": workspace, "session_id": session]] : []]
                case "workspace.remote.pty_detach":
                    try #require(scenario == .running)
                    expected.merge(["surface_id": surface, "session_id": session, "attachment_id": surface,
                                    "attachment_token": "attach-token", "allow_moved_surface": true]) { _, new in new }
                    result = ["detached": true]
                case "workspace.remote.pty_attach_end":
                    try #require(scenario == .gone || scenario == .reset)
                    expected["surface_id"] = surface; expected["session_id"] = session
                    result = ["cleared_remote_pty_session": true]
                default:
                    try #require(Bool(false), "Unexpected command or focus mutation: \(line)")
                }
                try #require(params as NSDictionary == expected as NSDictionary, "Wrong lifecycle payload: \(line)")
                return String(decoding: try JSONSerialization.data(withJSONObject: ["id": id, "ok": true, "result": result]), as: UTF8.self)
            }
            return try await server.capture {
                try await output.capture {
                    // The shell redirects before exec so CommandRunner's own output pipes immediately reach EOF.
                    await CommandRunner(environment: environment).run(directory: root.path, executable: "/bin/sh", arguments: [
                        "-c", "cli=$1; output=$2; errors=$3; shift 3; exec \"$cli\" \"$@\" </dev/null >\"$output\" 2>\"$errors\"",
                        "pty-lifecycle", cli, output.path, stderr.path,
                    ] + arguments, timeout: 5)
                }
            }
        }
        let ((result, stdout), lines) = captured.result
        if result.timedOut || result.executionError != nil {
            // These traces and output files belong only to this test's transports and child.
            let errors = Result { try String(contentsOf: stderr, encoding: .utf8) }
            try #require(!result.timedOut && result.executionError == nil,
                         "CLI did not complete: \(result); requests: \(lines); handshake: \(captured.handshake); resize acknowledgement observed: \(captured.resized); input ended: \(captured.inputEnded); bridge closed: \(captured.closed); stdout: \(stdout); stderr: \(errors)")
        }
        let errors = try String(contentsOf: stderr, encoding: .utf8)
        #expect(result.exitStatus == (scenario == .running ? 254 : 0), "\(errors)")
        #expect(stdout.isEmpty, "\(stdout)")
        if scenario == .running {
            #expect(errors.contains("ssh-pty-attach: bridge closed while remote PTY session is still running"), "\(errors)")
        } else { #expect(errors.isEmpty, "\(errors)") }
        try #require(captured.closed, "Bridge never reached the required close boundary")
        let handshake = try #require(JSONSerialization.jsonObject(with: Data(captured.handshake.utf8)) as? [String: Any])
        #expect(handshake["token"] as? String == "bridge-token")
        #expect(handshake["cols"] as? Int == columns && handshake["rows"] as? Int == rows)
        #expect((handshake["client_pid"] as? Int ?? 0) > 0)
        let requests = try lines.map { try #require(JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any]) }
        let methods = try requests.map { try #require($0["method"] as? String) }
        let resize = "workspace.remote.pty_resize"
        var lifecycle = ["workspace.remote.pty_bridge", "workspace.remote.pty_sessions"]
        if scenario == .running { lifecycle.append("workspace.remote.pty_detach") }
        else if hasSurface { lifecycle.append("workspace.remote.pty_attach_end") }
        #expect(methods.filter { $0 != resize } == lifecycle, "\(methods)")
        if waitsForResize { #expect(methods == [lifecycle[0], resize] + lifecycle.dropFirst(), "\(methods)") }
        else { #expect(methods.filter { $0 == resize }.count <= 1, "\(methods)") }
        let attachments = requests.compactMap { ($0["params"] as? [String: Any])?["attachment_id"] as? String }
        #expect(Set(attachments).count == 1, "Attachment identity changed across lifecycle calls")
    }
}
