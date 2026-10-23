import Darwin
import Foundation
import Testing

@Suite(.serialized) struct CLITmuxCompatRemoteSplitTests {
    @Test func splitPrintCarriesPreMutationRemoteRejection() async throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: CLITmuxCompatRemoteSplitBundleToken.self)
        let root = URL(fileURLWithPath: "/tmp").appendingPathComponent("tmux-split-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record(error, "Could not remove owned tmux split fixture directory") }
        }
        let socketPath = root.appendingPathComponent("socket").path
        let workspaceId = "11111111-1111-1111-1111-111111111111"
        let surfaceId = "22222222-2222-2222-2222-222222222222"
        let server = CLISocketFixture(path: socketPath) { line in
            guard let payload = Self.jsonObject(line),
                  let id = payload["id"] as? String,
                  let method = payload["method"] as? String else {
                return Self.malformedRequestResponse(raw: line)
            }
            switch method {
            case "surface.list":
                return Self.v2Response(id: id, ok: true, result: [
                    "surfaces": [["id": surfaceId, "ref": "surface:1", "index": 0, "focused": true]],
                ])
            case "surface.split":
                let params = payload["params"] as? [String: Any] ?? [:]
                #expect(params["workspace_id"] as? String == workspaceId, "workspace_id did not match")
                #expect(params["surface_id"] as? String == surfaceId, "surface_id did not match")
                #expect(params["remote_tmux_unsupported_options"] as? [String] == ["-P"],
                    "surface.split did not carry remote_tmux_unsupported_options=[\"-P\"]")
                return Self.v2Response(id: id, ok: false, error: [
                    "code": "invalid_params",
                    "message": "Not supported when targeting a remote tmux mirror workspace (the request is routed to tmux and these options cannot be applied): -P",
                ])
            default:
                return Self.v2Response(id: id, ok: false, error: ["code": "unsupported", "message": method])
            }
        }
        let (outcome, commands) = try await server.capture {
            // Join the CLI on both outcomes before the socket's final drain releases its descriptors.
            do {
                return Result<ShellContractProcess.Result, any Error>.success(try await ShellContractProcess(
                    root: root, deadline: .seconds(30), terminationGrace: .milliseconds(200)
                ).run(executable: cliPath, arguments: ["__tmux-compat", "split-window", "-P"], environment: [
                    "BMUX_SOCKET_PATH": socketPath, "BMUX_WORKSPACE_ID": workspaceId, "BMUX_SURFACE_ID": surfaceId,
                    "HOME": root.path, "CFFIXED_USER_HOME": root.path,
                    "PATH": ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin",
                    "BMUX_CLI_SENTRY_DISABLED": "1",
                ]))
            } catch { return .failure(error) }
        }
        let result: ShellContractProcess.Result
        do { result = try outcome.get() }
        catch {
            let output = Result { try String(contentsOf: root.appendingPathComponent("stdout"), encoding: .utf8) }
            let errors = Result { try String(contentsOf: root.appendingPathComponent("stderr"), encoding: .utf8) }
            Issue.record(error, "Tmux split failed after requests: \(commands); stdout: \(output); stderr: \(errors)")
            throw error
        }
        #expect(result.status != 0)
        #expect(result.stderr.contains("Not supported when targeting a remote tmux mirror workspace"), Comment(rawValue: result.stderr))
        #expect(!result.stderr.contains("already applied"), Comment(rawValue: result.stderr))
    }

    private func serverCompleted(_ signal: DispatchSemaphore) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: signal.wait(timeout: .now() + 30) == .success)
            }
        }
    }

    private final class CapturedRespawn: @unchecked Sendable {
        private let lock = NSLock()
        private var commandValue: String?
        private var startCommandValue: String?

        func record(command: String?, startCommand: String?) {
            lock.lock()
            commandValue = command
            startCommandValue = startCommand
            lock.unlock()
        }

        var command: String? {
            lock.lock(); defer { lock.unlock() }
            return commandValue
        }

        var startCommand: String? {
            lock.lock(); defer { lock.unlock() }
            return startCommandValue
        }
    }

    /// Drives `__tmux-compat respawn-pane -k -- <command>` against a mock socket
    /// and returns the `command` / `tmux_start_command` forwarded to
    /// `surface.respawn`.
    private func respawnPaneForwardedCommand(
        _ command: String,
        extraEnvironment: [String: String] = [:]
    ) async throws -> (command: String, startCommand: String) {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: CLITmuxCompatRemoteSplitBundleToken.self)
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-tmux-compat-respawn-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let socketPath = Self.makeSocketPath("tmuxresp")
        let listenerFD = try Self.bindUnixSocket(at: socketPath)
        defer {
            Darwin.close(listenerFD)
            unlink(socketPath)
        }

        let workspaceId = "11111111-1111-1111-1111-111111111111"
        let surfaceId = "22222222-2222-2222-2222-222222222222"
        let captured = CapturedRespawn()
        let state = ServerState()
        let handled = Self.startMockServer(listenerFD: listenerFD, state: state) { reqLine in
            guard let payload = Self.jsonObject(reqLine),
                  let id = payload["id"] as? String,
                  let method = payload["method"] as? String else {
                return Self.malformedRequestResponse(raw: reqLine)
            }
            switch method {
            case "surface.list":
                return Self.v2Response(id: id, ok: true, result: [
                    "surfaces": [["id": surfaceId, "ref": "surface:1", "index": 0, "focused": true]],
                ])
            case "surface.respawn":
                let params = payload["params"] as? [String: Any] ?? [:]
                captured.record(
                    command: params["command"] as? String,
                    startCommand: params["tmux_start_command"] as? String
                )
                return Self.v2Response(id: id, ok: true, result: [:])
            default:
                return Self.v2Response(id: id, ok: false, error: ["code": "unsupported", "message": method])
            }
        }

        var environment = [
            "BMUX_SOCKET_PATH": socketPath,
            "BMUX_WORKSPACE_ID": workspaceId,
            "BMUX_SURFACE_ID": surfaceId,
            "HOME": tmpDir.path,
            "PATH": ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin",
            "BMUX_CLI_SENTRY_DISABLED": "1",
        ]
        for (key, value) in extraEnvironment {
            environment[key] = value
        }
        let result = try await ShellContractProcess(
            root: tmpDir, deadline: .seconds(30), terminationGrace: .milliseconds(200)
        ).run(
            executable: cliPath,
            arguments: ["__tmux-compat", "respawn-pane", "-k", "--", command],
            environment: environment
        )
        #expect(await serverCompleted(handled))
        #expect(state.errorSnapshot() == [])
        #expect(result.terminatedNormally, Comment(rawValue: result.stderr))
        #expect(result.status == 0, Comment(rawValue: result.stderr))
        guard let forwarded = captured.command, let startCommand = captured.startCommand else {
            throw CLITmuxCompatRespawnTestError.noRespawnCommand
        }
        return (forwarded, startCommand)
    }

    /// Regression for #6447: Claude Code 2.1.183 launches agent-team teammates by
    /// creating a placeholder pane (`split-window -- cat`) and then running the real
    /// teammate command via `respawn-pane -k -- "cd <dir> && env … <claude> …"`. bmux
    /// forwards that command to the surface as the pane's process command. On macOS,
    /// Ghostty execs the surface command via `exec -l <command>` (ghostty
    /// src/termio/Exec.zig), which only works for a single executable — a bare shell
    /// expression like `cd … && … claude` makes it try to exec the `cd` builtin as a
    /// binary, the pane exits immediately, and the teammate never gets a visible pane
    /// (it falls back to in-process). The fix runs every tmux respawn shell-command
    /// through a POSIX shell (/bin/sh) so Ghostty execs the shell, not the expression.
    /// `tmux_start_command` stays the raw command so `#{pane_start_command}` / OMX-HUD
    /// detection keep reporting it.
    @Test func respawnPaneRunsShellExpressionsThroughLoginShell() async throws {
        let shellPrefix = "/bin/sh -c "

        // Claude Code teammate command: spaced `cd … && … claude` shell expression.
        let teammate = "cd /tmp/work && env CLAUDECODE=1 /opt/claude --agent-id alice@team --agent-name alice"
        let teammateResult = try await respawnPaneForwardedCommand(teammate)
        #expect(
            teammateResult.command.hasPrefix(shellPrefix),
            "teammate command must run through /bin/sh -c, got: \(teammateResult.command)"
        )
        #expect(
            teammateResult.command.contains(teammate),
            "shell-invoked command must carry the original command verbatim, got: \(teammateResult.command)"
        )
        #expect(
            teammateResult.startCommand == teammate,
            "tmux_start_command must stay the raw command for display/OMX detection, got: \(teammateResult.startCommand)"
        )

        // Operator without surrounding whitespace must still be wrapped.
        let noSpaceOperator = try await respawnPaneForwardedCommand("echo one;echo two")
        #expect(
            noSpaceOperator.command.hasPrefix(shellPrefix),
            "non-whitespace-separated operator must still be wrapped, got: \(noSpaceOperator.command)"
        )

        // A leading `NAME=value` assignment is shell syntax (`exec` cannot run a
        // program literally named `FOO=bar`), so it must be wrapped even with no
        // operators present.
        let assignmentPrefix = try await respawnPaneForwardedCommand("FOO=bar /opt/claude --resume x")
        #expect(
            assignmentPrefix.command.hasPrefix(shellPrefix),
            "assignment-prefixed command must be wrapped, got: \(assignmentPrefix.command)"
        )

        // A `<shell> -c "…"` form (e.g. OMO) is wrapped too: it is run through one
        // more shell that execs straight into it, so there is no fragile attempt
        // to tell "already shelled" commands apart from shell expressions that
        // hide trailing operators with no whitespace (`-c "x";y`). The original is
        // carried verbatim inside the wrapper.
        let shellForm = try await respawnPaneForwardedCommand("/bin/sh -c \"opencode attach; sleep 1\"")
        #expect(
            shellForm.command.hasPrefix(shellPrefix),
            "shell-invocation command must be wrapped, got: \(shellForm.command)"
        )
        #expect(
            shellForm.command.contains("/bin/sh -c \"opencode attach; sleep 1\""),
            "wrapper must carry the original command verbatim, got: \(shellForm.command)"
        )
    }

    /// Regression for #6447: even after the teammate command runs through a shell,
    /// each spawned `claude` opened its pane but then blocked forever on Claude
    /// Code's interactive "Do you trust this folder?" gate and never checked in —
    /// which looked like the teammate "failing to start". Claude Code short-circuits
    /// that gate on `CLAUDE_CODE_SANDBOXED`. Teammate panes are respawned by bmux
    /// (not by `bmux claude-teams`), so they do not inherit the launcher env and must
    /// be re-supplied it. Because the gate is a real safety boundary, bmux waives it
    /// only when the launcher recorded the user's `--dangerously-skip-permissions`
    /// opt-in in `BMUX_CLAUDE_TEAMS_SANDBOXED` — the decision is NOT re-derived from
    /// the respawn command text. OMO and the public `respawn-pane` never see that env
    /// and are unaffected.
    @Test func respawnPaneInjectsClaudeTeamsTrustBypass() async throws {
        // No --dangerously-skip-permissions substring in the command: the bypass must
        // come purely from the launcher's recorded opt-in marker.
        let teammate = "cd /tmp/work && env CLAUDECODE=1 /opt/claude --agent-id alice@team --agent-name alice"

        let inTeams = try await respawnPaneForwardedCommand(
            teammate,
            extraEnvironment: ["BMUX_CLAUDE_TEAMS_SANDBOXED": "1"]
        )
        #expect(
            inTeams.command.hasPrefix("/bin/sh -c "),
            "claude-teams respawn must still run through /bin/sh -c, got: \(inTeams.command)"
        )
        #expect(
            inTeams.command.contains("export CLAUDE_CODE_SANDBOXED="),
            "an opted-in claude-teams respawn must export CLAUDE_CODE_SANDBOXED, got: \(inTeams.command)"
        )
        #expect(
            inTeams.command.contains(teammate),
            "the original teammate command must still be carried verbatim, got: \(inTeams.command)"
        )
        #expect(
            inTeams.startCommand == teammate,
            "tmux_start_command must stay the raw command (no injected env), got: \(inTeams.startCommand)"
        )

        // A bare `--dangerously-skip-permissions` substring in the command must NOT
        // grant the bypass on its own — only the recorded opt-in marker does.
        let substringOnly = try await respawnPaneForwardedCommand(
            "cd '/tmp/--dangerously-skip-permissions' && /opt/claude --agent-id a@t --agent-name a"
        )
        #expect(
            !substringOnly.command.contains("CLAUDE_CODE_SANDBOXED"),
            "a command substring must not grant the trust bypass without the opt-in marker, got: \(substringOnly.command)"
        )

        // No marker (OMO / public respawn-pane / non-opted-in claude-teams): no injection.
        let outsideTeams = try await respawnPaneForwardedCommand(teammate)
        #expect(
            !outsideTeams.command.contains("CLAUDE_CODE_SANDBOXED"),
            "without the opt-in marker, respawn must not inject CLAUDE_CODE_SANDBOXED, got: \(outsideTeams.command)"
        )
    }

    private enum CLITmuxCompatRespawnTestError: Error {
        case noRespawnCommand
    }

    private final class CLITmuxCompatRemoteSplitBundleToken {}

    private final class ServerState: @unchecked Sendable {
        private let lock = NSLock()
        private var errors: [String] = []

        func expect(_ condition: Bool, _ message: String) {
            guard !condition else { return }
            lock.lock()
            errors.append(message)
            lock.unlock()
        }

        func errorSnapshot() -> [String] {
            lock.lock()
            let value = errors
            lock.unlock()
            return value
        }
    }

    private static func makeSocketPath(_ name: String) -> String {
        let shortID = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cli-\(name.prefix(6))-\(shortID).sock")
            .path
    }

    private static func bindUnixSocket(at path: String) throws -> Int32 {
        unlink(path)
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let maxPathLength = MemoryLayout.size(ofValue: addr.sun_path)
        let utf8 = Array(path.utf8)
        guard utf8.count < maxPathLength else {
            Darwin.close(fd)
            throw NSError(domain: "bmux.tests", code: Int(ENAMETOOLONG), userInfo: [
                NSLocalizedDescriptionKey: "Unix socket path is too long: \(path)",
            ])
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: maxPathLength) { buffer in
                for index in 0..<utf8.count {
                    buffer[index] = CChar(bitPattern: utf8[index])
                }
                buffer[utf8.count] = 0
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.bind(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            Darwin.close(fd)
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        guard Darwin.listen(fd, 1) == 0 else {
            Darwin.close(fd)
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        return fd
    }

    private static func startMockServer(
        listenerFD: Int32,
        state: ServerState,
        handler: @escaping @Sendable (String) -> String
    ) -> DispatchSemaphore {
        let handled = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            defer { handled.signal() }

            var clientAddr = sockaddr_un()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
            let clientFD = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    Darwin.accept(listenerFD, sockaddrPtr, &clientAddrLen)
                }
            }
            guard clientFD >= 0 else {
                state.expect(false, "mock socket server failed to accept a client")
                return
            }
            defer { Darwin.close(clientFD) }

            var pending = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let count = Darwin.read(clientFD, &buffer, buffer.count)
                if count < 0 {
                    if errno == EINTR { continue }
                    state.expect(false, "mock socket server read failed with errno \(errno)")
                    return
                }
                if count == 0 { return }
                pending.append(buffer, count: count)

                while let newlineRange = pending.firstRange(of: Data([0x0A])) {
                    let lineData = pending.subdata(in: 0..<newlineRange.lowerBound)
                    pending.removeSubrange(0...newlineRange.lowerBound)
                    guard let line = String(data: lineData, encoding: .utf8) else { continue }
                    let response = handler(line) + "\n"
                    _ = response.withCString { ptr in
                        Darwin.write(clientFD, ptr, strlen(ptr))
                    }
                }
            }
        }
        return handled
    }

    private static func v2Response(
        id: String,
        ok: Bool,
        result: [String: Any]? = nil,
        error: [String: Any]? = nil
    ) -> String {
        var payload: [String: Any] = ["id": id, "ok": ok]
        if let result { payload["result"] = result }
        if let error { payload["error"] = error }
        let data = try? JSONSerialization.data(withJSONObject: payload, options: [])
        return String(data: data ?? Data("{}".utf8), encoding: .utf8) ?? "{}"
    }

    private static func malformedRequestResponse(id: String? = nil, raw: String) -> String {
        v2Response(
            id: id ?? "unknown",
            ok: false,
            error: ["code": "malformed_request", "message": "invalid or non-JSON payload", "raw": raw]
        )
    }

    private static func jsonObject(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    }
}
