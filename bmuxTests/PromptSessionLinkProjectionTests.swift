import BMUXAgentLaunch
import BmuxAgentChat
import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite struct PromptSessionLinkProjectionTests {
    @MainActor
    @Test func promptSubmitSessionLinkSurvivesThroughWorkspaceDisplayProjection() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
            try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let repositoryRoot = "/tmp/bmux-prompt-session-link-repo"
        let gitSnapshot = WorkProvenanceGitSnapshot(
            repositoryRoot: repositoryRoot,
            commonDirectory: "\(repositoryRoot)/.git",
            remoteSlug: "manaflow-ai/bmux",
            branch: "fix-workspace-tab-conversation-metadata",
            headCommit: "abc123",
            isDirty: false
        )
        let promptText = "Fix the PE session tab"
        let sessionID = "raw-codex-session"
        let observedAt = Date(timeIntervalSince1970: 1_725_000_321)
        let recorder = WorkProvenanceCodingAgentEvidenceRecorder(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [repositoryRoot: gitSnapshot])
        )

        try await recorder.recordTranscriptUserPrompts(
            record: AgentChatSessionRecord(
                sessionID: sessionID,
                agentKind: .codex,
                workspaceID: nil,
                surfaceID: nil,
                workingDirectory: repositoryRoot,
                transcriptPath: nil,
                state: .working(since: observedAt),
                lastActivityAt: observedAt,
                title: nil,
                pid: 321
            ),
            messages: [
                ChatMessage(
                    id: "line-1",
                    seq: 1,
                    role: .user,
                    timestamp: observedAt,
                    kind: .prose(ChatProse(text: promptText))
                )
            ]
        )

        let manager = TabManager()
        let workspace = manager.tabs[0]
        workspace.currentDirectory = repositoryRoot
        let promptOutcome = try #require(manager.handlePromptSubmit(
            workspaceId: workspace.id,
            message: " \(promptText) ",
            sessionID: " \(sessionID) ",
            iMessageModeEnabled: false
        ))
        #expect(promptOutcome.messageRecorded)

        let observationService = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [repositoryRoot: gitSnapshot]),
            dateProvider: { observedAt.addingTimeInterval(1) }
        )
        await observationService.observeWorkspaceSnapshot(WorkProvenanceWorkspaceSnapshot(workspace: workspace))

        let display = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(
            workspaceID: workspace.stableId.uuidString
        ))
        #expect(display.display?.lastSubmittedPrompt == promptText)
        #expect(display.display?.lastSubmittedPromptSessionID == sessionID)

        let runtime = WorkProvenanceRuntime(
            observationService: observationService,
            workspaceDisplayCurrentStateStore: WorkspaceDisplayCurrentStateStore(client: client),
            agentSessionFactualProjectionStore: AgentSessionFactualProjectionStore(client: client)
        )
        guard case .available(let projection) = await runtime.agentSessionFactualProjection(
            stableWorkspaceID: workspace.stableId
        ) else {
            Issue.record("Expected PE factual session projection for the prompt-linked workspace")
            return
        }

        #expect(projection.session.id == sessionID)
    }

    private struct FakeGitInspector: WorkProvenanceGitInspecting {
        let snapshotsByDirectory: [String: WorkProvenanceGitSnapshot]

        func snapshot(for directory: String) async -> WorkProvenanceGitSnapshot? {
            snapshotsByDirectory[directory]
        }
    }

    private struct StoreFixture {
        let root: URL
        let databaseURL: URL

        init() throws {
            root = FileManager.default.temporaryDirectory
                .appendingPathComponent("bmux-prompt-session-link-store-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            databaseURL = root.appendingPathComponent("provenance.sqlite", isDirectory: false)
        }

        func remove() {
            try? FileManager.default.removeItem(at: root)
        }
    }
}
