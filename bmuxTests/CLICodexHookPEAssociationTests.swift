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
