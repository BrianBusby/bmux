import BmuxFoundation
import Darwin
import Foundation
import Testing

/// Owns two prompt hooks, their persisted leases and the detached monitor processes.
final class CodexMonitorLeaseFixture {
    struct Lease: Decodable, Sendable {
        let leaseId: String
        let sessionId: String
        let turnId: String
        let workspaceId: String
        let surfaceId: String
        let retiredAt: Double?
    }

    struct Snapshot: Sendable {
        let leases: [Lease]
        let depth: Int
        let turns: [String]
        var active: [Lease] { leases.filter { $0.retiredAt == nil } }
    }

    let root = URL(fileURLWithPath: "/tmp").appendingPathComponent("codex-lease-\(UUID().uuidString)")
    let workspace = "11111111-1111-1111-1111-111111111111"
    let surface = "22222222-2222-2222-2222-222222222222"
    let session = "codex-session-lease-dedupe"
    let cli: String

    init() throws {
        cli = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func run(completedPriorTurn: Bool) async throws -> (first: Snapshot, second: Snapshot) {
        let server = CLISocketFixture(path: root.appendingPathComponent("socket").path, response: response)
        do {
            let (snapshots, _) = try await server.capture {
                try await prompt(turn: "turn-one", transcript: nil)
                let first = try snapshot()
                let transcript = root.appendingPathComponent("transcript.jsonl")
                if completedPriorTurn {
                    // A real terminal event distinguishes the next top-level turn from a nested prompt.
                    let event: [String: Any] = ["type": "event_msg", "payload": [
                        "type": "task_complete", "turn_id": "turn-one", "last_agent_message": "finished",
                    ]]
                    try (String(decoding: JSONSerialization.data(withJSONObject: event), as: UTF8.self) + "\n")
                        .write(to: transcript, atomically: true, encoding: .utf8)
                }
                try await prompt(turn: "turn-two", transcript: completedPriorTurn ? transcript : nil)
                let second = try snapshot()
                try await stopOwnedMonitors()
                return (first, second)
            }
            try FileManager.default.removeItem(at: root)
            return snapshots
        } catch {
            try await stopOwnedMonitors()
            try FileManager.default.removeItem(at: root)
            throw error
        }
    }

    private func prompt(turn: String, transcript: URL?) async throws {
        let input = root.appendingPathComponent("input"), output = root.appendingPathComponent("output")
        let errors = root.appendingPathComponent("errors")
        var payload: [String: Any] = [
            "session_id": session, "turn_id": turn, "cwd": root.path,
            "hook_event_name": "UserPromptSubmit", "prompt": turn == "turn-one" ? "first" : "second",
        ]
        if let transcript { payload["transcript_path"] = transcript.path }
        try JSONSerialization.data(withJSONObject: payload).write(to: input)
        let environment = [
            "HOME": root.path, "CFFIXED_USER_HOME": root.path, "XDG_CONFIG_HOME": root.path,
            "TMPDIR": root.path, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "CODEX_HOME": root.appendingPathComponent("codex").path,
            "BMUX_SOCKET_PATH": root.appendingPathComponent("socket").path,
            "BMUX_WORKSPACE_ID": workspace, "BMUX_SURFACE_ID": surface,
            "BMUX_CODEX_PID": String(getpid()), "BMUX_AGENT_HOOK_STATE_DIR": root.path,
            "BMUX_DEBUG_LOG": root.appendingPathComponent("debug.log").path,
            "BMUX_CLI_SENTRY_DISABLED": "1", "BMUX_SUPPRESS_SUBAGENT_NOTIFICATIONS": "1",
        ]
        // Positional owned files keep exact non-TTY bytes without blocking cooperative pipe readers.
        let result = await CommandRunner(environment: environment).run(
            directory: root.path, executable: "/bin/sh", arguments: [
                "-c", "exec \"$1\" hooks codex prompt-submit <\"$2\" >\"$3\" 2>\"$4\"",
                "codex-lease", cli, input.path, output.path, errors.path,
            ], timeout: 5
        )
        try #require(!result.timedOut)
        try #require(result.executionError == nil, "\(result.executionError ?? "")")
        #expect(result.exitStatus == 0)
        #expect(try String(contentsOf: output, encoding: .utf8) == "{}\n")
        #expect(try String(contentsOf: errors, encoding: .utf8) == "")
    }

    private func snapshot() throws -> Snapshot {
        let directory = root.appendingPathComponent("codex-monitor-leases")
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        var leases: [Lease] = []
        for url in urls {
            do {
                leases.append(try JSONDecoder().decode(Lease.self, from: Data(contentsOf: url)))
            } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
                // The live monitor may remove its retired record between enumeration and reading.
                continue
            }
        }
        let state = try #require(JSONSerialization.jsonObject(with: Data(contentsOf:
            root.appendingPathComponent("codex-hook-sessions.json"))) as? [String: Any])
        let sessions = try #require(state["sessions"] as? [String: [String: Any]])
        let record = try #require(sessions[session])
        return Snapshot(leases: leases, depth: try #require(record["activePromptDepth"] as? Int),
                        turns: try #require(record["activePromptTurnIds"] as? [String]))
    }

    private var response: @Sendable (String) throws -> String? {
        let workspace = workspace, surface = surface
        return { line in
            guard line.first == "{" else { return "OK" }
            let request = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            let method = try #require(request["method"] as? String)
            guard let id = request["id"] as? String else {
                #expect(method == "feed.push")
                return nil
            }
            let params = try #require(request["params"] as? [String: Any])
            let result: [String: Any]
            switch method {
            case "surface.list":
                try #require(params["workspace_id"] as? String == workspace)
                result = ["surfaces": [["id": surface, "ref": "surface:1", "focused": true]]]
            case "system.top": result = ["windows": []]
            case "workspace.list": result = ["workspaces": []]
            case "debug.terminals": result = ["terminals": []]
            case "workspace.set_auto_title": result = ["enabled": false]
            case "surface.resume.set", "surface.resume.clear": result = [:]
            default:
                Issue.record("Unexpected method: \(method)")
                return String(decoding: try JSONSerialization.data(withJSONObject: [
                    "id": id, "ok": false, "error": ["code": "unexpected", "message": method],
                ]), as: UTF8.self)
            }
            return String(decoding: try JSONSerialization.data(withJSONObject: [
                "id": id, "ok": true, "result": result,
            ]), as: UTF8.self)
        }
    }

    private func stopOwnedMonitors() async throws {
        let result = await CommandRunner(environment: ["PATH": "/usr/bin:/bin"]).run(
            directory: root.path, executable: "/bin/ps", arguments: ["-axo", "pid=,command="], timeout: 5
        )
        try #require(!result.timedOut && result.executionError == nil && result.exitStatus == 0)
        let processes = try #require(result.stdout)
        for line in processes.split(separator: "\n") {
            let fields = line.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
            guard fields.count == 2, let pid = Int32(fields[0]),
                  fields[1].hasPrefix(cli + " hooks codex monitor ")
                    || fields[1].hasPrefix("/usr/bin/nohup " + cli + " hooks codex monitor "),
                  fields[1].contains("--lease \(root.path)/codex-monitor-leases/") else { continue }
            // Native process-exit observation joins only this fixture's exact CLI and owned lease path.
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit)
                source.setEventHandler { source.cancel() }
                source.setCancelHandler { continuation.resume() }
                source.resume()
                if kill(pid, SIGTERM) != 0 {
                    let code = errno
                    #expect(code == ESRCH, "Could not terminate owned monitor: errno \(code)")
                    source.cancel()
                }
            }
        }
    }
}
