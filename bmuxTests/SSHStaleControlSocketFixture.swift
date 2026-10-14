import BmuxFoundation
import BmuxRemoteWorkspace
import Darwin
import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns the stale socket, generated startup command and managed attach boundary.
final class SSHStaleControlSocketFixture {
    let root = URL(fileURLWithPath: "/tmp").appendingPathComponent("ssh-control-\(UUID().uuidString)")
    let stalePath = "/tmp/bmux-ssh-\(getuid())-\(UUID().uuidString.prefix(8)).sock"
    let workspace = "11111111-1111-1111-1111-111111111111"
    let surface = "22222222-2222-2222-2222-222222222222"
    var session: String { "ssh-\(workspace)-\(surface)" }

    init() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        unlink(stalePath)
        try? FileManager.default.removeItem(at: root)
    }

    func run(cli: String) async throws -> (commands: [String], bridgeEvents: [String]) {
        try bindStaleSocket()
        try #require(FileManager.default.fileExists(atPath: stalePath))
        let ssh = root.appendingPathComponent("ssh")
        try """
        #!/bin/sh
        printf '%s\\n' "$*" >> "$BMUX_TEST_SSH_LOG"
        for arg in "$@"; do
          if [ "$arg" = '-G' ]; then printf 'controlpath %s\\n' "$BMUX_TEST_CONTROL_PATH"; exit 0; fi
        done
        previous_arg=
        for arg in "$@"; do
          if [ "$previous_arg" = '-O' ] && [ "$arg" = 'check' ]; then exit 255; fi
          previous_arg="$arg"
        done
        if [ -e "$BMUX_TEST_CONTROL_PATH" ]; then exit 99; fi
        exit 0
        """.write(to: ssh, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: ssh.path)

        let socket = root.appendingPathComponent("socket").path
        let environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path, "XDG_CONFIG_HOME": root.path,
            "TMPDIR": root.path, "PATH": "\(root.path):/usr/bin:/bin:/usr/sbin:/sbin",
            "BMUX_SOCKET_PATH": socket, "BMUX_BUNDLED_CLI_PATH": cli,
            "BMUX_WORKSPACE_ID": workspace, "BMUX_SURFACE_ID": surface,
            "BMUX_TEST_CONTROL_PATH": stalePath, "BMUX_TEST_SSH_LOG": root.appendingPathComponent("ssh.log").path,
            "BMUX_CLI_SENTRY_DISABLED": "1", "BMUX_SSH_RECONNECT_DELAY_SECONDS": "0",
        ]
        let generator = CLISocketFixture(path: socket, response: responder(endpoint: nil))
        let (_, generation) = try await generator.capture {
            try await runProcess(cli, arguments: [
                "ssh", "--no-focus", "--port", "2222",
                "--ssh-option", "ControlMaster auto", "--ssh-option", "ControlPersist 600",
                "--ssh-option", "ControlPath \(stalePath)", "bmux-macmini",
            ], environment: environment)
        }
        let requests = try generation.map(jsonObject)
        let configured = try #require(requests.first { $0["method"] as? String == "workspace.remote.configure" })
        let params = try #require(configured["params"] as? [String: Any])
        let startup = try #require(params["terminal_startup_command"] as? String)
        let client = SSHExitedPTYClient()
        let (stopped, stopSignal) = AsyncStream<Void>.makeStream()
        let bridge = RemotePTYBridgeServer(
            rpcClient: client, sessionID: session, attachmentID: surface,
            command: nil, requireExisting: false, strings: AppRemotePTYBridgeStrings(),
            onStop: { stopSignal.finish() }
        )
        do {
            let endpoint = try await withCheckedThrowingContinuation { continuation in
                // Legacy start blocks for listener readiness; isolate it from Swift's cooperative executor.
                Thread.detachNewThread { continuation.resume(with: Result { try bridge.start() }) }
            }
            let server = CLISocketFixture(path: socket, response: responder(endpoint: endpoint))
            let (_, commands) = try await server.capture {
                try await runProcess("/bin/sh", arguments: ["-c", startup], environment: environment)
            }
            bridge.stop()
            for await _ in stopped {}
            client.continuation.finish()
            var bridgeEvents: [String] = []
            for await event in client.events { bridgeEvents.append(event) }
            return (commands, bridgeEvents)
        } catch {
            bridge.stop()
            for await _ in stopped {}
            throw error
        }
    }

    private func runProcess(_ executable: String, arguments: [String], environment: [String: String]) async throws {
        let stdout = root.appendingPathComponent("stdout"), stderr = root.appendingPathComponent("stderr")
        let result = await CommandRunner(environment: environment).run(
            directory: root.path, executable: "/bin/sh", arguments: [
                "-c", "program=$1; output=$2; errors=$3; shift 3; exec \"$program\" \"$@\" </dev/null >\"$output\" 2>\"$errors\"",
                "ssh-control", executable, stdout.path, stderr.path,
            ] + arguments, timeout: 5
        )
        try #require(!result.timedOut)
        try #require(result.executionError == nil)
        let errors = try String(contentsOf: stderr, encoding: .utf8)
        #expect(result.exitStatus == 0, "\(errors)")
        #expect(errors.isEmpty, "\(errors)")
    }

    private func responder(endpoint: RemotePTYBridgeServer.Endpoint?) -> @Sendable (String) throws -> String? {
        let workspace = workspace, surface = surface, session = session, stalePath = stalePath
        return { line in
            let request = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            let id = try #require(request["id"] as? String)
            let method = try #require(request["method"] as? String)
            let params = try #require(request["params"] as? [String: Any])
            var result: [String: Any] = [:]
            switch method {
            case "workspace.create": result = ["workspace_id": workspace, "surface_id": surface]
            case "workspace.remote.configure":
                result = ["workspace_id": workspace, "workspace_ref": "workspace:9", "remote": ["enabled": true, "state": "connecting"]]
            case "workspace.remote.pty_bridge":
                let endpoint = try #require(endpoint)
                #expect(!FileManager.default.fileExists(atPath: stalePath), "Stale control socket must be removed before attach")
                #expect(params["workspace_id"] as? String == workspace)
                #expect(params["surface_id"] as? String == surface)
                #expect(params["session_id"] as? String == session)
                #expect(params["attachment_id"] as? String == surface)
                #expect(params["wait_for_ready"] as? Bool == true)
                result = ["host": endpoint.host, "port": endpoint.port, "token": endpoint.token]
            case "workspace.remote.pty_resize": result = ["resized": true]
            case "workspace.remote.pty_sessions": result = ["sessions": []]
            case "workspace.remote.pty_attach_end", "workspace.remote.terminal_session_end":
                #expect(params["workspace_id"] as? String == workspace)
                #expect(params["surface_id"] as? String == surface)
                if method.hasSuffix("pty_attach_end") { #expect(params["session_id"] as? String == session) }
            default: Issue.record("Unexpected method: \(method)")
            }
            return String(decoding: try JSONSerialization.data(withJSONObject: ["id": id, "ok": true, "result": result]), as: UTF8.self)
        }
    }

    private func bindStaleSocket() throws {
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        try #require(descriptor >= 0)
        defer { Darwin.close(descriptor) }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(stalePath.utf8) + [0]
        try #require(bytes.count <= MemoryLayout.size(ofValue: address.sun_path))
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        try #require(result == 0)
    }

    private func jsonObject(_ line: String) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
    }
}
