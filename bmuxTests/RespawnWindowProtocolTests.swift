import BmuxFoundation
import Foundation
import Testing

@Suite
final class RespawnWindowProtocolTests {
    @Test(arguments: [
        ["--window", "window:2", "echo", "fresh"],
        ["echo", "fresh", "--window", "window:2"],
        ["--window", "window:2", "--command", "echo fresh"],
    ])
    func windowOptionStaysOutOfRespawnCommand(arguments: [String]) async throws {
        let root = URL(fileURLWithPath: "/tmp").appendingPathComponent("respawn-window-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let socket = root.appendingPathComponent("socket").path
        let stdout = root.appendingPathComponent("stdout"), stderr = root.appendingPathComponent("stderr")
        let window = "11111111-1111-1111-1111-111111111111"
        let workspace = "22222222-2222-2222-2222-222222222222"
        let surface = "33333333-3333-3333-3333-333333333333"
        let server = CLISocketFixture(path: socket) { line in
            let request = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            let id = try #require(request["id"] as? String)
            let method = try #require(request["method"] as? String)
            let params = try #require(request["params"] as? [String: Any])
            let result: [String: Any]
            switch method {
            case "window.list": result = ["windows": [["id": window, "ref": "window:2", "index": 2]]]
            case "system.identify":
                #expect(params["window_id"] as? String == window)
                result = ["focused": ["window_id": window, "workspace_id": workspace, "surface_id": surface]]
            case "surface.respawn":
                #expect(params["window_id"] as? String == window)
                #expect(params["surface_id"] as? String == surface)
                #expect(params["tmux_start_command"] as? String == "echo fresh")
                result = ["surface_id": surface]
            default:
                Issue.record("Unexpected respawn method: \(method)")
                return String(decoding: try JSONSerialization.data(withJSONObject:
                    ["id": id, "ok": false, "error": ["code": "unexpected", "message": method]]), as: UTF8.self)
            }
            return String(decoding: try JSONSerialization.data(withJSONObject:
                ["id": id, "ok": true, "result": result]), as: UTF8.self)
        }
        let runner = CommandRunner(environment: [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "SHELL": "/bin/sh",
            "BMUX_SOCKET_PATH": socket, "BMUX_CLI_SENTRY_DISABLED": "1",
        ])
        let cli = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let (result, commands) = try await server.capture {
            await runner.run(directory: root.path, executable: "/bin/sh", arguments: [
                "-c", "program=$1; output=$2; errors=$3; shift 3; exec \"$program\" \"$@\" </dev/null >\"$output\" 2>\"$errors\"",
                "respawn-window", cli, stdout.path, stderr.path, "respawn-pane",
            ] + arguments, timeout: 5)
        }
        try #require(!result.timedOut)
        try #require(result.executionError == nil)
        let errors = try String(contentsOf: stderr, encoding: .utf8)
        #expect(result.exitStatus == 0, "\(errors)")
        #expect(errors.isEmpty, "\(errors)")
        #expect(try String(contentsOf: stdout, encoding: .utf8) == "OK\n")
        let requests = try commands.map { try #require(JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any]) }
        #expect(requests.compactMap { $0["method"] as? String } == ["window.list", "system.identify", "surface.respawn"])
        let respawn = try #require(requests.first { $0["method"] as? String == "surface.respawn" })
        let params = try #require(respawn["params"] as? [String: Any])
        let command = try #require(params["command"] as? String)
        // Exercise the emitted shell command, not just its stored original text.
        let execution = await runner.run(directory: root.path, executable: "/bin/sh", arguments: [
            "-c", "exec /bin/sh -c \"$1\" </dev/null >\"$2\" 2>\"$3\"",
            "respawn-command", command, stdout.path, stderr.path,
        ], timeout: 5)
        try #require(!execution.timedOut)
        try #require(execution.executionError == nil)
        #expect(execution.exitStatus == 0)
        #expect(try String(contentsOf: stdout, encoding: .utf8) == "fresh\n")
        #expect(try String(contentsOf: stderr, encoding: .utf8) == "")
    }
}
