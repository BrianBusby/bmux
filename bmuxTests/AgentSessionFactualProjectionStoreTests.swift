import Foundation
import ProvenanceEngineContracts
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
@MainActor
struct AgentSessionFactualProjectionStoreTests {
    @Test
    func blankSessionIDReturnsMissingSessionWithoutReadingPE() async {
        let client = FakeProvenanceEngineClient()
        let store = AgentSessionFactualProjectionStore(client: client)

        #expect(store.snapshot(sessionID: "  ") == .missingSession)
        #expect(await store.refreshedSnapshot(sessionID: "\n") == .missingSession)
        #expect(await client.factualProjectionRequests() == [])
    }

    @Test
    func refreshReadsFactualProjectionWithBoundedTurnLimit() async throws {
        let snapshot = Self.snapshot(sessionID: "session-1", revision: 42)
        let client = FakeProvenanceEngineClient(factualProjectionResults: [
            .success(ProvenanceFactualSessionProjectionResponse(
                found: true,
                sessionID: "session-1",
                snapshot: snapshot
            ))
        ])
        let store = AgentSessionFactualProjectionStore(client: client)

        #expect(await store.refreshedSnapshot(sessionID: " session-1 ") == .available(snapshot))
        #expect(store.snapshot(sessionID: "session-1") == .available(snapshot))

        let request = try #require(await client.factualProjectionRequests().first)
        #expect(request.sessionID == "session-1")
        #expect(request.turnLimit == 12)
    }

    @Test
    func refreshFailurePreservesCachedSnapshot() async {
        let snapshot = Self.snapshot(sessionID: "session-1", revision: 7)
        let client = FakeProvenanceEngineClient(factualProjectionResults: [
            .success(ProvenanceFactualSessionProjectionResponse(
                found: true,
                sessionID: "session-1",
                snapshot: snapshot
            )),
            .failure(TestError.unavailable)
        ])
        let store = AgentSessionFactualProjectionStore(client: client)

        #expect(await store.refreshedSnapshot(sessionID: "session-1") == .available(snapshot))
        #expect(await store.refreshedSnapshot(sessionID: "session-1") == .available(snapshot))
        #expect(await client.factualProjectionRequests().count == 2)
    }

    @Test
    func notFoundRemovesCachedSnapshot() async {
        let snapshot = Self.snapshot(sessionID: "session-1", revision: 3)
        let client = FakeProvenanceEngineClient(factualProjectionResults: [
            .success(ProvenanceFactualSessionProjectionResponse(
                found: true,
                sessionID: "session-1",
                snapshot: snapshot
            )),
            .success(ProvenanceFactualSessionProjectionResponse(
                found: false,
                reason: "missing",
                sessionID: "session-1",
                snapshot: nil
            ))
        ])
        let store = AgentSessionFactualProjectionStore(client: client)

        #expect(await store.refreshedSnapshot(sessionID: "session-1") == .available(snapshot))
        #expect(await store.refreshedSnapshot(sessionID: "session-1") == .notFound(sessionID: "session-1", reason: "missing"))
        #expect(store.snapshot(sessionID: "session-1") == .notFound(sessionID: "session-1", reason: nil))
    }

    @Test
    func refreshFailureWithoutCacheReturnsFailure() async {
        let client = FakeProvenanceEngineClient(factualProjectionResults: [
            .failure(TestError.unavailable)
        ])
        let store = AgentSessionFactualProjectionStore(client: client)

        #expect(await store.refreshedSnapshot(sessionID: "session-1") == .failed(sessionID: "session-1"))
    }

    @Test
    func smartSessionRefreshReturnsAvailableFactualSnapshot() async {
        let snapshot = Self.snapshot(sessionID: "session-1", revision: 42)
        let client = FakeProvenanceEngineClient(factualProjectionResults: [
            .success(ProvenanceFactualSessionProjectionResponse(
                found: true,
                sessionID: "session-1",
                snapshot: snapshot
            ))
        ])
        let store = AgentSessionSmartSessionStore(client: client)

        guard case let .available(smartSnapshot) = await store.refreshedSnapshot(sessionID: "session-1") else {
            Issue.record("Expected available Smart Session snapshot")
            return
        }

        #expect(smartSnapshot.identity.sessionID == "session-1")
        #expect(smartSnapshot.factual.latestTurn?.turnID == "turn-1")
        #expect(smartSnapshot.revision.factualRevision == 42)
    }

    private static func snapshot(sessionID: String, revision: Int) -> ProvenanceFactualSessionProjectionSnapshot {
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
            priorTurns: [],
            turns: [turnSnapshot]
        )
    }
}

private actor FakeProvenanceEngineClient: ProvenanceEngineClient {
    private var factualProjectionResults: [Result<ProvenanceFactualSessionProjectionResponse, Error>]
    private var requests: [ProvenanceFactualSessionProjectionRequest] = []

    init(factualProjectionResults: [Result<ProvenanceFactualSessionProjectionResponse, Error>] = []) {
        self.factualProjectionResults = factualProjectionResults
    }

    func factualProjectionRequests() -> [ProvenanceFactualSessionProjectionRequest] {
        requests
    }

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
