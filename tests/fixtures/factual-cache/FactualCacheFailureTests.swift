import Foundation
import ProvenanceEngineContracts
import Testing
@testable import Store

@Suite @MainActor
struct FactualCacheFailureTests {
    @Test func refreshFailureDoesNotPresentCachedFactsAsCurrent() async {
        let snapshot = Self.snapshot(sessionID: "session-1", revision: 7)
        let client = FakeProvenanceEngineClient(factualProjectionResults: [
            .success(ProvenanceFactualSessionProjectionResponse(found: true, sessionID: "session-1", snapshot: snapshot)),
            .failure(TestError.unavailable)
        ])
        let store = AgentSessionFactualProjectionStore(client: client)
        #expect(await store.refreshedSnapshot(sessionID: "session-1") == .available(snapshot))
        let afterFailure = await store.refreshedSnapshot(sessionID: "session-1")
        // Historical data can be retained, but an error must be distinguishable
        // from a healthy current read. A future stale-with-snapshot case is valid.
        if case .available = afterFailure {
            Issue.record("Refresh failure returned an unmarked available snapshot")
        }
        #expect(afterFailure != .missingSession)
        #expect(await client.factualProjectionRequests().count == 2)
    }

    private static func snapshot(
        sessionID: String,
        revision: Int,
        priorPrompt: String? = nil
    ) -> ProvenanceFactualSessionProjectionSnapshot {
        let updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let thread = ProvenanceCodingAgentThreadRecord(
            id: "thread-1",
            sessionID: sessionID,
            provider: "codex",
            providerThreadID: "provider-thread-1",
            worktreeID: "worktree-1",
            source: .observed,
            confidence: .high,
            firstObservedAt: updatedAt,
            updatedAt: updatedAt
        )
        let priorTurn = priorPrompt.map { _ in
            ProvenanceCodingAgentTurnRecord(
                id: "turn-0",
                sessionID: sessionID,
                threadID: thread.id,
                provider: "codex",
                providerTurnID: "provider-turn-0",
                status: "completed",
                model: "gpt-5-codex",
                startedAt: updatedAt.addingTimeInterval(-120),
                completedAt: updatedAt.addingTimeInterval(-60),
                updatedAt: updatedAt.addingTimeInterval(-60),
                source: .observed,
                confidence: .high
            )
        }
        let priorTurnSnapshot = priorTurn.map { turn in
            ProvenanceFactualSessionProjectionTurnSnapshot(
                turn: turn,
                submittedPrompt: ProvenanceCodingAgentPromptRecord(
                    id: "prompt-0",
                    sessionID: sessionID,
                    threadID: thread.id,
                    turnID: turn.id,
                    provider: "codex",
                    text: priorPrompt ?? "",
                    submittedAt: updatedAt.addingTimeInterval(-120),
                    source: .observed,
                    confidence: .high
                ),
                currentPlan: nil,
                completedCommands: [],
                visibleReasoningSummaries: [],
                fileChangeAttributions: [],
                assistantMessages: [
                    ProvenanceCodingAgentAssistantMessageRecord(
                        id: "assistant-message-0",
                        sessionID: sessionID,
                        threadID: thread.id,
                        turnID: turn.id,
                        provider: "codex",
                        itemID: "assistant-message-item-0",
                        text: "Final.",
                        completedAt: updatedAt.addingTimeInterval(-60),
                        source: .observed,
                        confidence: .high
                    )
                ]
            )
        }
        let turn = ProvenanceCodingAgentTurnRecord(
            id: "turn-1",
            sessionID: sessionID,
            threadID: thread.id,
            provider: "codex",
            providerTurnID: "provider-turn-1",
            status: "completed",
            model: "gpt-5-codex",
            startedAt: updatedAt,
            completedAt: updatedAt.addingTimeInterval(60),
            updatedAt: updatedAt.addingTimeInterval(60),
            source: .observed,
            confidence: .high
        )
        let turnSnapshot = ProvenanceFactualSessionProjectionTurnSnapshot(
            turn: turn,
            submittedPrompt: ProvenanceCodingAgentPromptRecord(
                id: "prompt-1",
                sessionID: sessionID,
                threadID: thread.id,
                turnID: turn.id,
                provider: "codex",
                text: "Show factual session data",
                submittedAt: updatedAt,
                source: .observed,
                confidence: .high
            ),
            currentPlan: nil,
            completedCommands: [],
            visibleReasoningSummaries: [],
            fileChangeAttributions: []
        )
        return ProvenanceFactualSessionProjectionSnapshot(
            revision: revision,
            session: ProvenanceSessionRecord(
                id: sessionID,
                agentKind: "codex",
                workspaceID: "workspace-1",
                surfaceID: "surface-1",
                worktreeID: "worktree-1",
                cwd: "/repo",
                status: "active",
                startedAt: updatedAt,
                updatedAt: updatedAt
            ),
            providerThreadIdentities: [
                ProvenanceFactualSessionProjectionProviderThreadIdentity(thread: thread)
            ],
            providerThreads: [thread],
            latestTurn: turnSnapshot,
            priorTurns: priorTurn.map { [ProvenanceFactualSessionProjectionTurnReference(turn: $0)] } ?? [],
            turns: (priorTurnSnapshot.map { [$0] } ?? []) + [turnSnapshot]
        )
    }


}

private actor FakeProvenanceEngineClient: ProvenanceEngineClient {
    private var factualProjectionResults: [Result<ProvenanceFactualSessionProjectionResponse, Error>]
    private var sessionWorkModelResults: [Result<ProvenanceSessionWorkModelResponse, Error>]
    private var requests: [ProvenanceFactualSessionProjectionRequest] = []
    private var workModelRequests: [ProvenanceSessionWorkModelRequest] = []

    init(
        factualProjectionResults: [Result<ProvenanceFactualSessionProjectionResponse, Error>] = [],
        sessionWorkModelResults: [Result<ProvenanceSessionWorkModelResponse, Error>] = []
    ) {
        self.factualProjectionResults = factualProjectionResults
        self.sessionWorkModelResults = sessionWorkModelResults
    }

    func factualProjectionRequests() -> [ProvenanceFactualSessionProjectionRequest] { requests }

    func sessionWorkModelRequests() -> [ProvenanceSessionWorkModelRequest] { workModelRequests }

    func health() async throws -> ProvenanceEngineHealth {
        ProvenanceEngineHealth(status: .available, version: "test", capabilities: [])
    }

    func appendEvent(
        _ request: ProvenanceEngineContracts.ProvenanceAppendEventRequest
    ) async throws -> ProvenanceEngineContracts.ProvenanceAppendEventResponse {
        throw TestError.unimplemented
    }

    func recordSessionLifecycle(_ request: ProvenanceSessionLifecycleRequest) async -> ProvenanceSessionLifecycleResponse {
        ProvenanceSessionLifecycleResponse(
            accepted: false,
            eventID: nil,
            sessionID: nil,
            relationshipSessionID: nil,
            externalIdentityID: nil
        )
    }

    func sessionTree(_ request: ProvenanceSessionTreeRequest) async throws -> ProvenanceSessionTreeResponse {
        throw TestError.unimplemented
    }

    func fileExplanation(_ request: ProvenanceFileExplanationRequest) async throws -> ProvenanceFileExplanationResponse {
        throw TestError.unimplemented
    }

    func worktrees(_ request: ProvenanceWorktreeListRequest) async throws -> ProvenanceWorktreeListResponse {
        throw TestError.unimplemented
    }

    func currentContext(
        _ request: ProvenanceEngineContracts.ProvenanceCurrentContextRequest
    ) async throws -> ProvenanceEngineContracts.ProvenanceCurrentContextResponse {
        throw TestError.unimplemented
    }

    func workspaceDisplay(_ request: ProvenanceWorkspaceDisplayRequest) async throws -> ProvenanceWorkspaceDisplayResponse {
        throw TestError.unimplemented
    }

    func factualSessionProjection(
        _ request: ProvenanceFactualSessionProjectionRequest
    ) async throws -> ProvenanceFactualSessionProjectionResponse {
        requests.append(request)
        guard !factualProjectionResults.isEmpty else {
            throw TestError.unimplemented
        }
        return try factualProjectionResults.removeFirst().get()
    }

    func sessionWorkModel(_ request: ProvenanceSessionWorkModelRequest) async throws -> ProvenanceSessionWorkModelResponse {
        workModelRequests.append(request)
        return try sessionWorkModelResults.removeFirst().get()
    }

    func publishSemanticMessage(
        _ request: ProvenanceSemanticMessagePublishRequest
    ) async throws -> ProvenanceSemanticMessagePublishResponse {
        throw TestError.unimplemented
    }

    func semanticMessages(
        _ request: ProvenanceSemanticMessageQueryRequest
    ) async throws -> ProvenanceSemanticMessageQueryResponse {
        _ = request
        return ProvenanceSemanticMessageQueryResponse(records: [])
    }

    func materializeSemanticMessages(
        _ request: ProvenanceSemanticMessageMaterializationRequest
    ) async throws -> ProvenanceSemanticMessageMaterializationResponse {
        throw TestError.unimplemented
    }

    func publishCodingAgentSessionSemanticInferences(
        _ request: ProvenanceCodingAgentSessionSemanticInferenceRequest
    ) async throws -> ProvenanceCodingAgentSessionSemanticInferenceResponse {
        throw TestError.unimplemented
    }
}

private enum TestError: Error {
    case unavailable
    case unimplemented
}
