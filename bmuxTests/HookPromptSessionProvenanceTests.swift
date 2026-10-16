import Foundation
import BMUXAgentLaunch
import BmuxAgentChat
import ProvenanceEngineContracts
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct HookPromptSessionProvenanceTests {
    @Test
    func hookPromptSubmitRecordsFactualSessionAndWorkspaceDisplayLink() async throws {
        let client = CapturingProvenanceEngineClient()
        let recorder = WorkProvenanceCodingAgentEvidenceRecorder(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [
                "/repo": WorkProvenanceGitSnapshot(
                    repositoryRoot: "/repo",
                    commonDirectory: "/repo/.git",
                    remoteSlug: "manaflow-ai/bmux",
                    branch: "fix-session-view-terminal-overlay",
                    headCommit: "abc123",
                    isDirty: false
                )
            ])
        )
        let stableWorkspaceID = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_725_000_123)
        let record = AgentChatSessionRecord(
            sessionID: "raw-codex-session",
            agentKind: .codex,
            workspaceID: "runtime-workspace",
            surfaceID: "surface-1",
            workingDirectory: "/repo",
            transcriptPath: nil,
            state: .working(since: timestamp),
            lastActivityAt: timestamp,
            title: nil,
            pid: 123
        )
        let event = WorkstreamEvent(
            sessionId: "codex-raw-codex-session",
            hookEventName: .userPromptSubmit,
            source: "codex",
            workspaceId: "runtime-workspace",
            surfaceId: "surface-1",
            cwd: "/repo",
            context: WorkstreamContext(lastUserMessage: "Fix the PE session tab"),
            requestId: "hook-request-1",
            ppid: 123,
            receivedAt: timestamp
        )

        try await recorder.recordHookUserPromptSubmit(
            record: record,
            event: event,
            stableWorkspaceID: stableWorkspaceID
        )

        let requests = await client.appendedEventRequests
        let request = try #require(requests.first)
        #expect(requests.count == 1)
        #expect(request.event.eventType == .codingAgentPromptSubmitted)
        #expect(request.event.sessionID == "raw-codex-session")
        #expect(request.event.evidenceOrigin == .codexSession)
        #expect(request.event.confidence == .medium)

        let session = try #require(request.event.payload.session)
        #expect(session.id == "raw-codex-session")
        #expect(session.agentKind == "codex")
        #expect(session.workspaceID == stableWorkspaceID.uuidString)
        #expect(session.surfaceID == "surface-1")
        #expect(session.cwd == "/repo")
        #expect(session.status == "active")

        let turn = try #require(request.event.payload.codingAgentTurn)
        let prompt = try #require(request.event.payload.codingAgentPrompt)
        #expect(turn.sessionID == "raw-codex-session")
        #expect(turn.provider == "codex")
        #expect(turn.status == "started")
        #expect(turn.confidence == .medium)
        let legacyHookTurnSeed = "raw-codex-session\nhook-request-1\ncodex-raw-codex-session\n\(timestamp.timeIntervalSince1970)\nFix the PE session tab"
        let stableIDFactory = WorkProvenanceStableIDFactory()
        let expectedSyntheticProviderTurnID = stableIDFactory.id(prefix: "hook-codex-turn", value: legacyHookTurnSeed)
        #expect(turn.providerTurnID == expectedSyntheticProviderTurnID)
        #expect(prompt.sessionID == "raw-codex-session")
        #expect(prompt.turnID == turn.id)
        #expect(prompt.id == stableIDFactory.id(prefix: "coding-agent-prompt", value: "hook\nraw-codex-session\n\(expectedSyntheticProviderTurnID)\nFix the PE session tab"))
        #expect(prompt.text == "Fix the PE session tab")
        #expect(prompt.confidence == .medium)
        #expect(request.event.id == "event-\(stableIDFactory.id(prefix: "hook-codex-prompt", value: legacyHookTurnSeed))")

        let display = try #require(request.event.payload.workspaceDisplay)
        #expect(display.workspaceID == stableWorkspaceID.uuidString)
        #expect(display.currentDirectory == "/repo")
        #expect(display.lastSubmittedPrompt == "Fix the PE session tab")
        #expect(display.lastSubmittedPromptSessionID == "raw-codex-session")
        #expect(display.worktreeID == WorkProvenanceStableIDFactory().worktreeID(repositoryRoot: "/repo"))

        try await recorder.recordTranscriptUserPrompts(
            record: record,
            messages: [
                ChatMessage(id: "line-12", seq: 12, role: .user, timestamp: timestamp.addingTimeInterval(10), kind: .prose(ChatProse(text: "Backfilled transcript prompt"))),
                ChatMessage(id: "line-13", seq: 13, role: .agent, timestamp: timestamp.addingTimeInterval(11), kind: .prose(ChatProse(text: "Agent response"))),
            ],
            stableWorkspaceID: stableWorkspaceID
        )
        let backfillRequests = await client.appendedEventRequests
        let backfillRequest = try #require(backfillRequests.last)
        #expect(backfillRequests.count == 2)
        #expect(backfillRequest.event.payload.codingAgentTurn == nil)
        #expect(backfillRequest.event.payload.codingAgentPrompt?.text == "Backfilled transcript prompt")
        #expect(backfillRequest.event.payload.codingAgentPrompt?.turnID == nil)
        #expect(backfillRequest.event.payload.workspaceDisplay?.lastSubmittedPromptSessionID == "raw-codex-session")
    }
    private struct FakeGitInspector: WorkProvenanceGitInspecting {
        let snapshotsByDirectory: [String: WorkProvenanceGitSnapshot]

        func snapshot(for directory: String) async -> WorkProvenanceGitSnapshot? {
            snapshotsByDirectory[directory]
        }
    }
}
