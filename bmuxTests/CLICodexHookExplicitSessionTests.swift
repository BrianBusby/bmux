import Darwin
import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

@Suite(.serialized)
struct CLICodexHookExplicitSessionTests {
    @Test func missingSessionStillReconcilesTerminalTurnDuringPromptTitle() throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: BundledCLILinkageTests.self)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bmux-codex-title-stop-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let socketPath = makeCodexHookSocketPath("title-stop")
        let listener = try bindCodexHookUnixSocket(at: socketPath)
        defer { Darwin.close(listener); unlink(socketPath); try? FileManager.default.removeItem(at: root) }
        let workspace = "11111111-1111-1111-1111-111111111111"
        let surface = "22222222-2222-2222-2222-222222222222"
        let commands = CodexHookCapturedSocketCommands()
        let environment = ["HOME": root.path, "CFFIXED_USER_HOME": root.path, "BMUX_PROVENANCE_HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "PWD": root.path, "BMUX_SOCKET_PATH": socketPath,
            "BMUX_WORKSPACE_ID": workspace, "BMUX_SURFACE_ID": surface, "BMUX_AGENT_HOOK_STATE_DIR": root.path,
            "BMUX_CLI_SENTRY_DISABLED": "1", "BMUX_CODEX_HOOK_IDENTITY_VERIFIED": "1", "BMUX_CODEX_PID": String(getpid())]
        startCodexHookMockSocketServerAccepting(listenerFD: listener, commands: commands, surfaceId: surface,
            connectionLimit: 32, responseOverride: { line in
                guard let frame = codexHookJSONObject(line), frame["method"] as? String == "workspace.set_auto_title",
                      let params = frame["params"] as? [String: Any], params["probe"] as? Bool == true,
                      let id = frame["id"] as? String else { return nil }
                do {
                    try injectTerminalTurn(root: root, session: surface, turn: "turn-1")
                    commands.append("fixture-terminal-state-written")
                } catch {
                    commands.append("fixture-terminal-state-failed")
                }
                return codexHookV2Response(id: id, ok: true, result: ["enabled": false])
            })
        let prompt = runCodexHookProcess(executablePath: cliPath, arguments: ["hooks", "codex", "prompt-submit"],
            environment: environment, standardInput: #"{"turn_id":"turn-1","prompt":"Fix bmux workspace titles after prompt submit"}"#, timeout: 15)
        #expect(!prompt.timedOut && prompt.status == 0, Comment(rawValue: prompt.stderr))
        let frames = commands.snapshot()
        #expect(frames.contains("fixture-terminal-state-written"))
        #expect(frames.contains { $0.hasPrefix("set_agent_lifecycle codex idle ") },
                "The prompt must reconcile the terminal turn after the title probe")
    }

    @Test(arguments: ["session-start", "prompt-submit"], ["{}", #"{"session_id":"   "}"#])
    func codexHookWithoutSessionDoesNotInventProvenanceIdentity(action: String, payload: String) async throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: BundledCLILinkageTests.self)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bmux-codex-missing-session-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let socketPath = makeCodexHookSocketPath("missing-session")
        let listener = try bindCodexHookUnixSocket(at: socketPath)
        defer { Darwin.close(listener); unlink(socketPath); try? FileManager.default.removeItem(at: root) }
        let workspace = "11111111-1111-1111-1111-111111111111"
        let stable = "33333333-3333-3333-3333-333333333333"
        let surface = "22222222-2222-2222-2222-222222222222"
        let commands = CodexHookCapturedSocketCommands()
        startCodexHookMockSocketServerAccepting(listenerFD: listener, commands: commands, surfaceId: surface,
            connectionLimit: 32, runtimeWorkspaceId: workspace, stableWorkspaceId: stable)
        let environment = ["HOME": root.path, "CFFIXED_USER_HOME": root.path, "BMUX_PROVENANCE_HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "PWD": root.path, "BMUX_SOCKET_PATH": socketPath,
            "BMUX_WORKSPACE_ID": workspace, "BMUX_STABLE_WORKSPACE_ID": stable, "BMUX_SURFACE_ID": surface,
            "BMUX_AGENT_HOOK_STATE_DIR": root.path, "BMUX_CLI_SENTRY_DISABLED": "1",
            "BMUX_CODEX_HOOK_IDENTITY_VERIFIED": "1", "BMUX_CODEX_PID": String(getpid())]
        let hook = runCodexHookProcess(executablePath: cliPath, arguments: ["hooks", "codex", action],
            environment: environment, standardInput: payload, timeout: 10)
        #expect(!hook.timedOut && hook.status == 0, Comment(rawValue: hook.stderr))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("codex-hook-sessions.json").path))
        let expectedLifecycle = action == "session-start" ? "unknown" : "running"
        #expect(commands.snapshot().contains {
            $0.hasPrefix("set_agent_lifecycle codex \(expectedLifecycle) ") && $0.contains("--panel=\(surface)")
        })
        let association = try await codexHookPEAssociationResponse(root: root, stableWorkspaceId: stable)
        #expect(!association.found)
        let leases = root.appendingPathComponent("codex-monitor-leases", isDirectory: true)
        #expect((try? FileManager.default.contentsOfDirectory(atPath: leases.path).isEmpty) ?? true)

        let recovery = runCodexHookProcess(executablePath: cliPath, arguments: ["hooks", "codex", "prompt-submit"],
            environment: environment, standardInput: #"{"session_id":"explicit-provider-session"}"#, timeout: 10)
        #expect(!recovery.timedOut && recovery.status == 0, Comment(rawValue: recovery.stderr))
        let recovered = try await codexHookPEAssociationResponse(root: root, stableWorkspaceId: stable)
        #expect(recovered.association?.sessionID == "explicit-provider-session")
        #expect(recovered.association?.surfaceID == surface)
    }

}

private func injectTerminalTurn(root: URL, session: String, turn: String) throws {
    let stateURL = root.appendingPathComponent("codex-hook-sessions.json")
    let fd = open(stateURL.path + ".lock", O_RDWR)
    guard fd >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    defer { Darwin.close(fd) }
    guard flock(fd, LOCK_EX) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    defer { _ = flock(fd, LOCK_UN) }
    guard var state = try JSONSerialization.jsonObject(with: Data(contentsOf: stateURL)) as? [String: Any],
          var sessions = state["sessions"] as? [String: Any],
          var record = sessions[session] as? [String: Any] else {
        throw NSError(domain: "fixture.missing-session", code: 1)
    }
    record["terminalPromptTurnIds"] = [turn]
    record["agentLifecycle"] = "idle"
    record["runtimeStatus"] = "idle"
    sessions[session] = record
    state["sessions"] = sessions
    try JSONSerialization.data(withJSONObject: state).write(to: stateURL, options: .atomic)
}
