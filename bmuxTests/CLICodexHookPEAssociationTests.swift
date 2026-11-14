import Darwin
import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

@Suite(.serialized)
struct CLICodexHookPEAssociationTests {
    @Test func codexPromptSubmitPersistsStableWorkspaceAssociationBeforeTranscriptImport() async throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: BundledCLILinkageTests.self)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-codex-hook-pe-association-\(UUID().uuidString)", isDirectory: true)
        let socketPath = makeCodexHookSocketPath("codex-pe")
        let listenerFD = try bindCodexHookUnixSocket(at: socketPath)
        let commands = CodexHookCapturedSocketCommands()
        let runtimeWorkspaceId = "11111111-1111-1111-1111-111111111111"
        let stableWorkspaceId = "33333333-3333-3333-3333-333333333333"
        let surfaceId = "22222222-2222-2222-2222-222222222222"
        let sessionId = "codex-hook-pe-association-session"
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            Darwin.close(listenerFD)
            unlink(socketPath)
            try? FileManager.default.removeItem(at: root)
        }
        startCodexHookMockSocketServerAccepting(
            listenerFD: listenerFD,
            commands: commands,
            surfaceId: surfaceId,
            connectionLimit: 16
        )

        let result = runCodexHookProcess(
            executablePath: cliPath,
            arguments: ["hooks", "codex", "prompt-submit"],
            environment: [
                "HOME": root.path,
                "CFFIXED_USER_HOME": root.path,
                "BMUX_PROVENANCE_HOME": root.path,
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                "PWD": root.path,
                "BMUX_SOCKET_PATH": socketPath,
                "BMUX_WORKSPACE_ID": runtimeWorkspaceId,
                "BMUX_STABLE_WORKSPACE_ID": stableWorkspaceId,
                "BMUX_SURFACE_ID": surfaceId,
                "BMUX_AGENT_HOOK_STATE_DIR": root.path,
                "BMUX_CLI_SENTRY_DISABLED": "1",
                "BMUX_CODEX_HOOK_IDENTITY_VERIFIED": "1",
                "BMUX_CODEX_PID": "4242",
            ],
            standardInput: #"{"session_id":"\#(sessionId)","turn_id":"turn-hook-1","cwd":"\#(root.path)","hook_event_name":"UserPromptSubmit"}"#,
            timeout: 5
        )

        #expect(!result.timedOut, Comment(rawValue: result.stderr))
        #expect(result.status == 0, Comment(rawValue: result.stderr))
        #expect(result.stdout == "{}\n")

        let response = try await peAssociationResponse(root: root, stableWorkspaceId: stableWorkspaceId)
        let association = try #require(response.association)
        #expect(response.found)
        #expect(response.readiness.status == .associationEstablishedProjectionPending)
        #expect(association.workspaceID == stableWorkspaceId)
        #expect(association.sessionID == sessionId)
        #expect(association.canonicalSessionID == sessionId)
        #expect(association.rawSessionID == sessionId)
        #expect(association.surfaceID == surfaceId)
        #expect(association.sourcePath == "hook")
        #expect(association.stage == "workspace_session_association_persisted")
        #expect(association.reasonCode == "hook_prompt_observed")
        #expect(association.promptObservedAt != nil)
    }

    @Test func unattestedCodexHookKeepsLifecycleButDoesNotBindProvenance() async throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: BundledCLILinkageTests.self)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bmux-unattested-hook-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let socketPath = makeCodexHookSocketPath("unattested-pe")
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
            "BMUX_AGENT_HOOK_STATE_DIR": root.path, "BMUX_CLI_SENTRY_DISABLED": "1", "BMUX_CODEX_PID": String(getpid())]
        let hook = runCodexHookProcess(executablePath: cliPath, arguments: ["hooks", "codex", "prompt-submit"],
            environment: environment,
            standardInput: #"{"session_id":"unattested-session","turn_id":"turn-1","hook_event_name":"UserPromptSubmit"}"#,
            timeout: 10)
        #expect(!hook.timedOut && hook.status == 0)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("codex-hook-sessions.json").path))
        let association = try await peAssociationResponse(root: root, stableWorkspaceId: stable)
        #expect(!association.found)
        var caller = environment
        caller["CODEX_THREAD_ID"] = "unattested-session"
        let retrieval = runCodexHookProcess(executablePath: cliPath,
            arguments: ["--json", "provenance", "sessions", "related", "--current"],
            environment: caller, timeout: 15)
        let response = try #require(try JSONSerialization.jsonObject(with: Data(retrieval.stdout.utf8)) as? [String: Any])
        #expect(response["reason"] as? String == "no_canonical_association")
        #expect(response["recovery_steps"] as? [String] == ["wait_for_hook_linkage", "refresh_codex_hooks_if_needed"])
        var unverified = environment
        unverified["BMUX_CODEX_HOOK_IDENTITY_VERIFIED"] = "0"
        let daemonHook = runCodexHookProcess(executablePath: cliPath, arguments: ["hooks", "codex", "prompt-submit"],
            environment: unverified,
            standardInput: #"{"session_id":"unverified-session","turn_id":"turn-2","hook_event_name":"UserPromptSubmit"}"#,
            timeout: 10)
        #expect(!daemonHook.timedOut && daemonHook.status == 0)
        let unverifiedAssociation = try await peAssociationResponse(root: root, stableWorkspaceId: stable)
        #expect(!unverifiedAssociation.found)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("codex-monitor-leases").path))
    }

    @Test func codexPromptSubmitResolvesStableWorkspaceFromRuntimeWorkspaceWhenEnvIsMissing() async throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: BundledCLILinkageTests.self)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-codex-hook-pe-runtime-association-\(UUID().uuidString)", isDirectory: true)
        let socketPath = makeCodexHookSocketPath("codex-pe")
        let listenerFD = try bindCodexHookUnixSocket(at: socketPath)
        let commands = CodexHookCapturedSocketCommands()
        let runtimeWorkspaceId = "11111111-1111-1111-1111-111111111111"
        let stableWorkspaceId = "33333333-3333-3333-3333-333333333333"
        let surfaceId = "22222222-2222-2222-2222-222222222222"
        let sessionId = "codex-hook-pe-runtime-association-session"
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            Darwin.close(listenerFD)
            unlink(socketPath)
            try? FileManager.default.removeItem(at: root)
        }
        startCodexHookMockSocketServerAccepting(
            listenerFD: listenerFD,
            commands: commands,
            surfaceId: surfaceId,
            connectionLimit: 16,
            runtimeWorkspaceId: runtimeWorkspaceId,
            stableWorkspaceId: stableWorkspaceId
        )

        let result = runCodexHookProcess(
            executablePath: cliPath,
            arguments: ["hooks", "codex", "prompt-submit"],
            environment: [
                "HOME": root.path,
                "CFFIXED_USER_HOME": root.path,
                "BMUX_PROVENANCE_HOME": root.path,
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                "PWD": root.path,
                "BMUX_SOCKET_PATH": socketPath,
                "BMUX_WORKSPACE_ID": runtimeWorkspaceId,
                "BMUX_SURFACE_ID": surfaceId,
                "BMUX_AGENT_HOOK_STATE_DIR": root.path,
                "BMUX_CLI_SENTRY_DISABLED": "1",
                "BMUX_CODEX_HOOK_IDENTITY_VERIFIED": "1",
                "BMUX_CODEX_PID": "4242",
            ],
            standardInput: #"{"session_id":"\#(sessionId)","turn_id":"turn-hook-1","cwd":"\#(root.path)","hook_event_name":"UserPromptSubmit"}"#,
            timeout: 5
        )

        #expect(!result.timedOut, Comment(rawValue: result.stderr))
        #expect(result.status == 0, Comment(rawValue: result.stderr))
        #expect(result.stdout == "{}\n")
        #expect(commands.snapshot().contains {
            codexHookJSONObject($0)?["method"] as? String == "workspace.list"
        })

        let response = try await peAssociationResponse(root: root, stableWorkspaceId: stableWorkspaceId)
        let association = try #require(response.association)
        #expect(response.found)
        #expect(response.readiness.status == .associationEstablishedProjectionPending)
        #expect(association.workspaceID == stableWorkspaceId)
        #expect(association.sessionID == sessionId)
        #expect(association.surfaceID == surfaceId)
        #expect(association.sourcePath == "hook")
        #expect(association.reasonCode == "hook_prompt_observed")
    }

    @Test func currentRelatedRejectsReusedSurfaceWithMultipleCodexHookSessions() async throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: BundledCLILinkageTests.self)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bmux-current-reuse-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let socketPath = makeCodexHookSocketPath("related-reuse")
        let listener = try bindCodexHookUnixSocket(at: socketPath)
        defer {
            Darwin.close(listener)
            unlink(socketPath)
            try? FileManager.default.removeItem(at: root)
        }
        let workspace = "11111111-1111-1111-1111-111111111111"
        let stable = "33333333-3333-3333-3333-333333333333"
        let surface = "22222222-2222-2222-2222-222222222222"
        let commands = CodexHookCapturedSocketCommands()
        startCodexHookMockSocketServerAccepting(listenerFD: listener, commands: commands, surfaceId: surface,
            connectionLimit: 40, runtimeWorkspaceId: workspace, stableWorkspaceId: stable)
        let environment = ["HOME": root.path, "CFFIXED_USER_HOME": root.path, "BMUX_PROVENANCE_HOME": root.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "PWD": root.path, "BMUX_SOCKET_PATH": socketPath,
            "BMUX_WORKSPACE_ID": workspace, "BMUX_STABLE_WORKSPACE_ID": stable, "BMUX_SURFACE_ID": surface,
            "BMUX_AGENT_HOOK_STATE_DIR": root.path, "BMUX_CLI_SENTRY_DISABLED": "1", "BMUX_CODEX_HOOK_IDENTITY_VERIFIED": "1", "BMUX_CODEX_PID": String(getpid())]
        func submit(_ session: String) {
            let result = runCodexHookProcess(executablePath: cliPath, arguments: ["hooks", "codex", "prompt-submit"],
                environment: environment,
                standardInput: #"{"session_id":"\#(session)","turn_id":"turn-\#(session)","cwd":"\#(root.path)","hook_event_name":"UserPromptSubmit"}"#,
                timeout: 10)
            #expect(!result.timedOut && result.status == 0, Comment(rawValue: result.stderr))
        }
        func query(_ session: String) throws -> [String: Any] {
            var caller = environment
            caller["CODEX_THREAD_ID"] = session
            let result = runCodexHookProcess(executablePath: cliPath,
                arguments: ["--json", "provenance", "sessions", "related", "--current"],
                environment: caller, timeout: 15)
            #expect(!result.timedOut && result.status == 0, Comment(rawValue: result.stderr))
            return try #require(try JSONSerialization.jsonObject(with: Data(result.stdout.utf8)) as? [String: Any])
        }
        submit("first-session")
        let first = try query("first-session")
        #expect(first["found"] as? Bool == true)
        submit("replacement-session")
        for session in ["first-session", "replacement-session"] {
            let result = try query(session)
            #expect(result["found"] as? Bool == false)
            #expect(result["reason"] as? String == "ambiguous_caller")
            #expect(result["recovery"] as? String == "start_fresh_pane")
        }
        var caller = environment
        caller["CODEX_THREAD_ID"] = "replacement-session"
        let text = runCodexHookProcess(executablePath: cliPath,
            arguments: ["provenance", "sessions", "related", "--current"], environment: caller, timeout: 15)
        #expect(text.stdout.contains("fresh pane"))
    }

    private func peAssociationResponse(
        root: URL,
        stableWorkspaceId: String
    ) async throws -> ProvenanceWorkspaceCodingAgentSessionAssociationResponse {
        let databaseURL = root
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("state", isDirectory: true)
            .appendingPathComponent("provenance-engine", isDirectory: true)
            .appendingPathComponent("provenance.sqlite", isDirectory: false)
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
            try ProvenanceEngineClientFactory().sqliteClient(databaseURL: databaseURL)
        return try await client.workspaceCodingAgentSessionAssociation(
            ProvenanceWorkspaceCodingAgentSessionAssociationRequest(workspaceID: stableWorkspaceId)
        )
    }
}
