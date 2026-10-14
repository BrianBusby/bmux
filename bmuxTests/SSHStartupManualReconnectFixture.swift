import BmuxFoundation
import Foundation
import Testing

/// Owns an isolated startup command, its protocol server and process capture files.
final class SSHStartupManualReconnectFixture {
    let root = URL(fileURLWithPath: "/tmp").appendingPathComponent("ssh-manual-\(UUID().uuidString)")

    var environment: [String: String] {
        [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path,
            "XDG_CONFIG_HOME": root.appendingPathComponent("config").path, "TMPDIR": root.path,
            "PATH": "\(root.path):/usr/bin:/bin:/usr/sbin:/sbin",
            "BMUX_CLI_SENTRY_DISABLED": "1", "BMUX_CLAUDE_HOOK_SENTRY_DISABLED": "1",
        ]
    }

    init() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    func generatedStartupCommand(bootstrap: Bool = false, reusable: Bool = false) async throws -> String {
        let cli = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let socket = root.appendingPathComponent("generator.sock").path
        let server = CLISocketFixture(path: socket, response: { try Self.response($0) })
        var environment = environment
        environment["BMUX_SOCKET_PATH"] = socket
        let (result, commands) = try await server.capture {
            try await runProcess(
                executablePath: cli,
                arguments: bootstrap ? [
                    "ssh", "--no-focus", "--port", "2222", "--ssh-option", "ControlMaster no",
                    "--ssh-option", "ControlPath /tmp/bmux-ssh-%C", "bmux-macmini",
                ] : ["vm", "ssh", "vm-test-startup"],
                environment: environment
            )
        }
        #expect(!result.timedOut, "\(result.stderr)")
        #expect(result.status == 0, "\(result.stderr)")
        #expect(result.stderr.isEmpty, "\(result.stderr)")
        let requests = try commands.map {
            try #require(JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any])
        }
        let request = try #require(requests.first {
            $0["method"] as? String == (reusable ? "workspace.remote.configure" : "workspace.create")
        })
        let params = try #require(request["params"] as? [String: Any])
        return try #require(params[reusable ? "terminal_startup_command" : "initial_command"] as? String)
    }

    func runProcess(
        executablePath: String, arguments: [String], environment: [String: String], standardInput: String = ""
    ) async throws -> (status: Int32, stdout: String, stderr: String, timedOut: Bool) {
        let input = root.appendingPathComponent("stdin")
        let output = root.appendingPathComponent("stdout")
        let errors = root.appendingPathComponent("stderr")
        try standardInput.write(to: input, atomically: true, encoding: .utf8)
        // Owned files avoid blocking cooperative-executor pipe drains while retaining exact process bytes.
        let result = await CommandRunner(environment: environment).run(
            directory: root.path, executable: "/bin/sh", arguments: [
                "-c", "program=$1; input=$2; output=$3; errors=$4; shift 4; exec \"$program\" \"$@\" <\"$input\" >\"$output\" 2>\"$errors\"",
                "ssh-manual", executablePath, input.path, output.path, errors.path,
            ] + arguments, timeout: 5
        )
        try #require(!result.timedOut)
        try #require(result.executionError == nil, "\(result.executionError ?? "")")
        let status = try #require(result.exitStatus)
        return (status, try String(contentsOf: output, encoding: .utf8),
                try String(contentsOf: errors, encoding: .utf8), result.timedOut)
    }

    func writeShellFile(at url: URL, lines: [String]) throws {
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func response(_ line: String) throws -> String? {
        let request = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
        let id = try #require(request["id"] as? String)
        let method = try #require(request["method"] as? String)
        let workspace = "11111111-1111-1111-1111-111111111111"
        var result: [String: Any] = [:]
        switch method {
        case "vm.ssh_info":
            let params = try #require(request["params"] as? [String: Any])
            try #require(params["id"] as? String == "vm-test-startup")
            try #require(Set(params.keys) == ["id"])
            result = [
                "transport": "ssh", "host": "gateway.freestyle.sh", "port": 2222, "username": "bmux",
                "credential": ["kind": "password", "value": "lease-token"],
            ]
        case "workspace.create":
            result = ["workspace_id": workspace, "surface_id": "22222222-2222-2222-2222-222222222222"]
        case "workspace.rename", "workspace.select": result = ["workspace_id": workspace]
        case "workspace.remote.configure":
            result = [
                "workspace_id": workspace, "workspace_ref": "workspace:vm-startup",
                "remote": ["enabled": true, "state": "connecting"],
            ]
        default:
            Issue.record("Unexpected method: \(method)")
            return String(decoding: try JSONSerialization.data(withJSONObject: [
                "id": id, "ok": false, "error": ["code": "unexpected", "message": method],
            ]), as: UTF8.self)
        }
        return String(decoding: try JSONSerialization.data(withJSONObject: ["id": id, "ok": true, "result": result]), as: UTF8.self)
    }
}
