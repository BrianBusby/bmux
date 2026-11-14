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

    @Test func staleClockIsStableAndRecoveryIsSessionScoped() async {
        let first = Self.snapshot(sessionID: "session-1", revision: 7)
        let other = Self.snapshot(sessionID: "session-2", revision: 3)
        let recovered = Self.snapshot(sessionID: "session-1", revision: 8)
        let client = FakeProvenanceEngineClient(factualProjectionResults: [
            .success(.init(found: true, sessionID: "session-1", snapshot: first)),
            .success(.init(found: true, sessionID: "session-2", snapshot: other)),
            .failure(TestError.unavailable), .failure(TestError.unavailable),
            .success(.init(found: true, sessionID: "session-1", snapshot: recovered)),
            .failure(TestError.unavailable),
            .success(.init(found: false, reason: "missing", sessionID: "session-1", snapshot: nil))
        ])
        var time = Date(timeIntervalSince1970: 100)
        let store = AgentSessionFactualProjectionStore(client: client, now: { time })
        #expect(await store.refreshedSnapshot(sessionID: "session-1") == .available(first))
        #expect(await store.refreshedSnapshot(sessionID: "session-2") == .available(other))
        time = Date(timeIntervalSince1970: 200)
        #expect(await store.refreshedSnapshot(sessionID: "session-1") == .stale(first, lastSuccessfulReadAt: Date(timeIntervalSince1970: 100)))
        #expect(store.snapshot(sessionID: "session-1") == .stale(first, lastSuccessfulReadAt: Date(timeIntervalSince1970: 100)))
        #expect(store.snapshot(sessionID: "session-2") == .available(other))
        time = Date(timeIntervalSince1970: 300)
        #expect(await store.refreshedSnapshot(sessionID: "session-1") == .stale(first, lastSuccessfulReadAt: Date(timeIntervalSince1970: 100)))
        #expect(await store.refreshedSnapshot(sessionID: "session-1") == .available(recovered))
        time = Date(timeIntervalSince1970: 400)
        #expect(await store.refreshedSnapshot(sessionID: "session-1") == .stale(recovered, lastSuccessfulReadAt: Date(timeIntervalSince1970: 300)))
        #expect(await store.refreshedSnapshot(sessionID: "session-1") == .notFound(sessionID: "session-1", reason: "missing"))
        #expect(store.snapshot(sessionID: "session-1") == .notFound(sessionID: "session-1", reason: nil))
    }

    @Test func foreignSessionResponseDoesNotReplaceCachedFacts() async {
        let expected = Self.snapshot(sessionID: "session-1", revision: 7)
        let foreign = Self.snapshot(sessionID: "session-2", revision: 8)
        let client = FakeProvenanceEngineClient(factualProjectionResults: [
            .success(.init(found: true, sessionID: "session-1", snapshot: expected)),
            .success(.init(found: true, sessionID: "session-1", snapshot: foreign)),
        ])
        let instant = Date(timeIntervalSince1970: 100)
        let store = AgentSessionFactualProjectionStore(client: client, now: { instant })
        #expect(await store.refreshedSnapshot(sessionID: "session-1") == .available(expected))
        #expect(await store.refreshedSnapshot(sessionID: "session-1") == .stale(expected, lastSuccessfulReadAt: instant))
        #expect(store.snapshot(sessionID: "session-2") == .notFound(sessionID: "session-2", reason: nil))
    }

    @Test func olderOverlappingFailureCannotOverrideNewerSuccess() async throws {
        let newer = Self.snapshot(sessionID: "session-1", revision: 8)
        let client = FakeProvenanceEngineClient(deferResponses: true)
        let store = AgentSessionFactualProjectionStore(client: client)
        let old = Task { await store.refreshedSnapshot(sessionID: "session-1") }
        try await client.waitForRequestCount(1)
        let new = Task { await store.refreshedSnapshot(sessionID: "session-1") }
        try await client.waitForRequestCount(2)
        await client.complete(1, with: .success(.init(found: true, sessionID: "session-1", snapshot: newer)))
        #expect(await new.value == .available(newer))
        await client.complete(0, with: .failure(TestError.unavailable))
        #expect(await old.value == .available(newer))
        #expect(store.snapshot(sessionID: "session-1") == .available(newer))
    }

    @Test(arguments: [false, true])
    func supersededResponseWhileNewerPendingIsNotHealthy(hasCache: Bool) async throws {
        for oldFails in [false, true] {
            let prior = Self.snapshot(sessionID: "session-1", revision: 7)
            let oldSnapshot = Self.snapshot(sessionID: "session-1", revision: 8)
            let client = FakeProvenanceEngineClient(deferResponses: true)
            let store = AgentSessionFactualProjectionStore(client: client)
            var index = 0
            if hasCache {
                let seed = Task { await store.refreshedSnapshot(sessionID: "session-1") }
                try await client.waitForRequestCount(1)
                await client.complete(0, with: .success(.init(found: true, sessionID: "session-1", snapshot: prior)))
                #expect(await seed.value == .available(prior))
                index = 1
            }
            let old = Task { await store.refreshedSnapshot(sessionID: "session-1") }
            try await client.waitForRequestCount(index + 1)
            let new = Task { await store.refreshedSnapshot(sessionID: "session-1") }
            try await client.waitForRequestCount(index + 2)
            if oldFails {
                await client.complete(index, with: .failure(TestError.unavailable))
            } else {
                await client.complete(index, with: .success(.init(found: true, sessionID: "session-1", snapshot: oldSnapshot)))
            }
            let oldResult = await old.value
            let synchronous = store.snapshot(sessionID: "session-1")
            if hasCache {
                #expect(oldResult != .available(prior))
                #expect(synchronous != .available(prior))
            } else {
                #expect(oldResult != .notFound(sessionID: "session-1", reason: nil))
                #expect(synchronous != .notFound(sessionID: "session-1", reason: nil))
            }
            await client.complete(index + 1, with: .failure(TestError.unavailable))
            _ = await new.value
            if !hasCache {
                #expect(store.snapshot(sessionID: "session-1") == .failed(sessionID: "session-1"))
            }
        }
    }

    @Test func olderSuccessCannotReplaceNewerFailure() async throws {
        let oldSnapshot = Self.snapshot(sessionID: "session-1", revision: 7)
        let client = FakeProvenanceEngineClient(deferResponses: true)
        let store = AgentSessionFactualProjectionStore(client: client)
        let old = Task { await store.refreshedSnapshot(sessionID: "session-1") }
        try await client.waitForRequestCount(1)
        let new = Task { await store.refreshedSnapshot(sessionID: "session-1") }
        try await client.waitForRequestCount(2)
        await client.complete(1, with: .failure(TestError.unavailable))
        #expect(await new.value == .failed(sessionID: "session-1"))
        await client.complete(0, with: .success(.init(found: true, sessionID: "session-1", snapshot: oldSnapshot)))
        #expect(await old.value == .failed(sessionID: "session-1"))
        #expect(store.snapshot(sessionID: "session-1") == .notFound(sessionID: "session-1", reason: nil))
    }

    @Test func olderOverlappingSuccessCannotResurrectNotFound() async throws {
        let oldSnapshot = Self.snapshot(sessionID: "session-1", revision: 7)
        let client = FakeProvenanceEngineClient(deferResponses: true)
        let store = AgentSessionFactualProjectionStore(client: client)
        let old = Task { await store.refreshedSnapshot(sessionID: "session-1") }
        try await client.waitForRequestCount(1)
        let new = Task { await store.refreshedSnapshot(sessionID: "session-1") }
        try await client.waitForRequestCount(2)
        await client.complete(1, with: .success(.init(found: false, reason: "missing", sessionID: "session-1", snapshot: nil)))
        #expect(await new.value == .notFound(sessionID: "session-1", reason: "missing"))
        await client.complete(0, with: .success(.init(found: true, sessionID: "session-1", snapshot: oldSnapshot)))
        #expect(await old.value == .notFound(sessionID: "session-1", reason: "missing"))
        #expect(store.snapshot(sessionID: "session-1") == .notFound(sessionID: "session-1", reason: nil))
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
    private let deferResponses: Bool
    private var continuations: [Int: CheckedContinuation<ProvenanceFactualSessionProjectionResponse, any Error>] = [:]
    private var workModelRequests: [ProvenanceSessionWorkModelRequest] = []

    init(
        factualProjectionResults: [Result<ProvenanceFactualSessionProjectionResponse, Error>] = [],
        sessionWorkModelResults: [Result<ProvenanceSessionWorkModelResponse, Error>] = [],
        deferResponses: Bool = false
    ) {
        self.deferResponses = deferResponses
        self.factualProjectionResults = factualProjectionResults
        self.sessionWorkModelResults = sessionWorkModelResults
    }

    func factualProjectionRequests() -> [ProvenanceFactualSessionProjectionRequest] { requests }

    func waitForRequestCount(_ count: Int) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        while requests.count < count {
            guard ContinuousClock.now < deadline else { throw TestError.requestTimeout }
            try await Task.sleep(for: .milliseconds(1))
        }
    }

    func complete(_ index: Int, with result: Result<ProvenanceFactualSessionProjectionResponse, any Error>) {
        continuations.removeValue(forKey: index)?.resume(with: result)
    }

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
        if deferResponses {
            let index = requests.count - 1
            return try await withCheckedThrowingContinuation { continuations[index] = $0 }
        }
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
    case requestTimeout
}
