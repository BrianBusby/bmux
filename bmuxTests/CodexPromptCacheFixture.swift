import Darwin
import Foundation
import Testing

@MainActor
final class CodexPromptCacheFixture {
    let root: URL
    let workspace = "33333333-3333-3333-3333-333333333333"
    let surface = "44444444-4444-4444-4444-444444444444"
    let session = "codex-auto-name-prompt-cache-session"
    let prompt = "debug first prompt workspace auto naming"
    private let cli: String

    init(cli: String) throws {
        self.cli = cli
        root = URL(fileURLWithPath: "/tmp/codex-cache-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func cleanup() {
        do { try FileManager.default.removeItem(at: root) }
        catch { Issue.record(error, "Could not remove owned Codex cache fixture") }
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    func run() async throws -> ShellContractProcess.Result {
        let fifo = root.appendingPathComponent("complete")
        guard mkfifo(fifo.path, 0o600) == 0 else { throw POSIXError(.EIO) }
        // O_RDWR keeps the final one-byte stub write nonblocking even if observation is cancelled.
        let descriptor = open(fifo.path, O_RDWR | O_NONBLOCK)
        guard descriptor >= 0 else { throw POSIXError(.EIO) }
        let (events, continuation) = AsyncStream<Int>.makeStream()
        let readiness = try CLISocketReadiness(descriptor: descriptor) { continuation.yield(1) }
        defer { continuation.finish() }
        do {
            let result = try await runHook(fifo: fifo)
            let deadline = ContinuousClock.now.advanced(by: .seconds(1))
            try await withThrowingTaskGroup(of: Void.self) { group in
                defer { group.cancelAll() }
                group.addTask {
                    for await _ in events {
                        var byte: UInt8 = 0
                        if read(descriptor, &byte, 1) == 1 { return }
                        readiness.acknowledge()
                    }
                    throw CancellationError()
                }
                group.addTask {
                    // Original one-second launcher observation bound, captured before task scheduling.
                    try await ContinuousClock().sleep(until: deadline)
                    throw CompletionFailure.missingLauncher
                }
                try await group.next()
            }
            // The final stub action completed all owned writes; this is not a waitpid exit join.
            await readiness.close()
            return result
        } catch {
            await readiness.close()
            throw error
        }
    }

    private func runHook(fifo: URL) async throws -> ShellContractProcess.Result {
        let input = root.appendingPathComponent("input")
        try Data(#"{"session_id":"\#(session)","cwd":"\#(root.path)","hook_event_name":"UserPromptSubmit","prompt":"\#(prompt)"}"#.utf8).write(to: input)
        let stub = root.appendingPathComponent("launcher")
        try """
        #!/bin/sh
        printf '%s\\n' "$@" > "$BMUX_AUTO_NAME_TRIGGER_LOG" || exit 73
        exec 9<>"$BMUX_TEST_COMPLETE_FIFO" || exit 72
        exec /usr/bin/printf '\\n' >&9
        """.write(to: stub, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stub.path)
        // Exercise the existing bundled fallback after its owned original path disappears.
        let launch = root.appendingPathComponent("cli-link")
        try FileManager.default.createSymbolicLink(atPath: launch.path, withDestinationPath: cli)
        let socket = root.appendingPathComponent("sock").path
        let environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path, "TMPDIR": root.path,
            "XDG_CONFIG_HOME": root.path, "XDG_STATE_HOME": root.path, "XDG_CACHE_HOME": root.path,
            "CODEX_HOME": root.appendingPathComponent("codex-home").path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "BMUX_UI_TEST_MODE": "1",
            "BMUX_SOCKET_PATH": socket, "BMUX_SOCKET_PASSWORD": "owned-codex-cache",
            "BMUX_WORKSPACE_ID": workspace, "BMUX_SURFACE_ID": surface,
            "BMUX_AGENT_HOOK_STATE_DIR": root.path, "BMUX_CLI_SENTRY_DISABLED": "1",
            "BMUX_AGENT_HOOK_SUPPRESS_VISIBLE_MUTATIONS": "1",
            "BMUX_BUNDLED_CLI_PATH": stub.path,
            "BMUX_AUTO_NAME_TRIGGER_LOG": root.appendingPathComponent("launch.log").path,
            "BMUX_TEST_COMPLETE_FIFO": fifo.path
        ]
        let surface = surface, workspace = workspace
        let server = CLISocketFixture(path: socket) { line in
            if line.hasPrefix("auth ") {
                try #require(line == "auth owned-codex-cache")
                if FileManager.default.fileExists(atPath: launch.path) {
                    try FileManager.default.removeItem(at: launch)
                }
                return "OK"
            }
            guard line.hasPrefix("{") else { return "OK" }
            let request = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            let method = try #require(request["method"] as? String)
            if method == "feed.push", request["id"] == nil { return nil }
            let id = try #require(request["id"] as? String)
            let result: [String: Any]
            switch method {
            case "surface.list":
                let params = try #require(request["params"] as? [String: Any])
                #expect(params["workspace_id"] as? String == workspace)
                result = ["surfaces": [["id": surface, "ref": "surface:1", "index": 1, "focused": true]]]
            case "workspace.set_auto_title": result = ["enabled": true, "workspace_user_owned": false, "summarizer_agent": "auto"]
            case "feed.push", "surface.resume.set": result = [:]
            default:
                return String(decoding: try JSONSerialization.data(withJSONObject: ["id": id, "ok": false, "error": ["code": "unrecognized_method", "message": "unexpected method"]]), as: UTF8.self)
            }
            return String(decoding: try JSONSerialization.data(withJSONObject: ["id": id, "ok": true, "result": result]), as: UTF8.self)
        }
        let runner = ShellContractProcess(root: root, deadline: .seconds(CLIProcessTestTimeout().seconds(5)))
        let (outcome, _) = try await server.capture { @Sendable in
            do {
                return .success(try await runner.run(executable: "/bin/bash", arguments: [
                    "--noprofile", "--norc", "-c", "exec \"$1\" hooks codex prompt-submit <\"$2\"", "cache", launch.path, input.path
                ], environment: environment)) as Result<ShellContractProcess.Result, Error>
            } catch { return .failure(error) }
        }
        return try outcome.get()
    }
    private enum CompletionFailure: Error { case missingLauncher }
}
