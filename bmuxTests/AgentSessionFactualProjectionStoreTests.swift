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
        let client = FakeProvenanceEngineClient(factualProjectionResults: [.failure(TestError.unavailable)])
        let store = AgentSessionFactualProjectionStore(client: client)

        #expect(await store.refreshedSnapshot(sessionID: "session-1") == .failed(sessionID: "session-1"))
    }

    @Test
    func smartSessionRefreshReturnsAvailableFactualSnapshot() async {
        let model = Self.workModel(sessionID: "session-1", revision: 42)
        let client = FakeProvenanceEngineClient(sessionWorkModelResults: [
            .success(ProvenanceSessionWorkModelResponse(
                found: true,
                sessionID: "session-1",
                model: model
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
        #expect(smartSnapshot.workModel.revision.modelRevisionKey == model.revision.modelRevisionKey)
        #expect(await client.sessionWorkModelRequests().first?.turnLimit == 12)
    }

    @Test
    func smartSessionRefreshKeepsNewerWorkModelRevision() async {
        let newerModel = Self.workModel(
            sessionID: "session-1",
            revision: 42,
            semanticCreatedAt: Date(timeIntervalSince1970: 1_800_000_200)
        )
        let olderModel = Self.workModel(
            sessionID: "session-1",
            revision: 42,
            semanticCreatedAt: Date(timeIntervalSince1970: 1_800_000_100)
        )
        let client = FakeProvenanceEngineClient(sessionWorkModelResults: [
            .success(ProvenanceSessionWorkModelResponse(
                found: true,
                sessionID: "session-1",
                model: newerModel
            )),
            .success(ProvenanceSessionWorkModelResponse(
                found: true,
                sessionID: "session-1",
                model: olderModel
            ))
        ])
        let store = AgentSessionSmartSessionStore(client: client)

        guard case let .available(firstSnapshot) = await store.refreshedSnapshot(sessionID: "session-1"),
              case let .available(secondSnapshot) = await store.refreshedSnapshot(sessionID: "session-1") else {
            Issue.record("Expected available Smart Session snapshots")
            return
        }

        #expect(firstSnapshot.revision.key == secondSnapshot.revision.key)
        #expect(
            secondSnapshot.workModel.revision.latestSemanticInferenceCreatedAt ==
            newerModel.revision.latestSemanticInferenceCreatedAt
        )
    }

    @Test
    func smartSessionBridgeLocalizesSemanticLabelsWithoutReplacingRawPayload() throws {
        let model = Self.workModel(
            sessionID: "session-1",
            revision: 42,
            activityBasis: "file_change_attribution",
            sessionPhase: .waitingBlocked
        )
        let smartSnapshot = AgentSessionSmartSessionSnapshot(workModel: model, semanticMessages: [])
        let phaseRecord = try #require(smartSnapshot.workModel.sessionPhase.record)
        let phasePayload = try #require(ProvenanceCodingAgentSessionPhasePayload(semanticPayloadValue: phaseRecord.payload))
        let currentActivity = try #require(smartSnapshot.workModel.currentTurn?.currentActivity)
        let activityRecord = try #require(currentActivity.record)
        let activityPayload = try #require(ProvenanceCodingAgentCurrentActivityPayload(semanticPayloadValue: activityRecord.payload))
        let phaseLabel = String(localized: "agentSession.web.smartSession.phase.waiting", defaultValue: "Waiting")
        let basisDetail = String(localized: "agentSession.web.smartSession.activityBasis.fileChangeAttribution", defaultValue: "Based on file changes")

        #expect(smartSnapshot.workModel.sessionPhase.summary == phaseLabel)
        #expect(smartSnapshot.workModel.sessionPhase.summary != "waiting_blocked")
        #expect(phasePayload.phase == .waitingBlocked)
        #expect(currentActivity.detail == basisDetail)
        #expect(currentActivity.detail != "file_change_attribution")
        #expect(activityPayload.basis == "file_change_attribution")
    }

    @Test
    func factualProjectionEvidenceRowsUseLatestCompactSlice() {
        #expect(AgentSessionFactualProjectionEvidenceRows.latestRows(["a", "b", "c", "d"], limit: 2) == ["c", "d"])
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

    private static func workModel(
        sessionID: String,
        revision: Int,
        semanticCreatedAt: Date = Date(timeIntervalSince1970: 1_800_000_120),
        activityBasis: String = "coding_agent_prompt",
        sessionPhase: ProvenanceCodingAgentSessionPhase? = nil
    ) -> ProvenanceSessionWorkModel {
        let factualProjection = snapshot(sessionID: sessionID, revision: revision)
        let threadIdentity = factualProjection.providerThreadIdentities[0]
        let turnSnapshot = factualProjection.latestTurn!
        let currentActivityRecord = semanticRecord(
            id: "inference-current-activity-\(Int(semanticCreatedAt.timeIntervalSince1970))",
            kind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
            scope: .turn,
            scopeID: turnSnapshot.turn.id,
            payload: ProvenanceCodingAgentCurrentActivityPayload(
                activityKind: .implementation,
                summary: "Rendering Smart Session from SessionWorkModel",
                basis: activityBasis
            ).semanticPayloadValue,
            factualRevision: revision,
            createdAt: semanticCreatedAt
        )
        let phaseRecord = sessionPhase.map { phase in
            semanticRecord(
                id: "inference-session-phase-\(Int(semanticCreatedAt.timeIntervalSince1970))",
                kind: ProvenanceCodingAgentSemanticInferenceKind.sessionPhase.rawValue,
                scope: .session,
                scopeID: sessionID,
                payload: ProvenanceCodingAgentSessionPhasePayload(
                    phase: phase,
                    reason: "Waiting on external input",
                    signals: ["test"]
                ).semanticPayloadValue,
                factualRevision: revision,
                createdAt: semanticCreatedAt
            )
        }
        let semanticRecords = [currentActivityRecord] + (phaseRecord.map { [$0] } ?? [])
        return ProvenanceSessionWorkModel(
            revision: ProvenanceSessionWorkModelRevision(
                factualRevision: revision,
                semanticInferenceIDs: semanticRecords.map(\.id),
                latestSemanticInferenceCreatedAt: semanticRecords.map(\.createdAt).max()
            ),
            identity: ProvenanceSessionWorkModelIdentity(
                session: factualProjection.session,
                providerThreadIdentities: factualProjection.providerThreadIdentities
            ),
            thread: ProvenanceSessionWorkModelThread(
                identity: threadIdentity,
                intent: semanticField(
                    kind: ProvenanceCodingAgentSemanticInferenceKind.threadIntent.rawValue,
                    scope: .thread,
                    scopeID: threadIdentity.threadID
                )
            ),
            currentTurn: ProvenanceSessionWorkModelCurrentTurn(
                turn: turnSnapshot.turn,
                prompt: turnSnapshot.submittedPrompt,
                plan: turnSnapshot.currentPlan,
                completedCommands: turnSnapshot.completedCommands,
                visibleReasoningSummaries: turnSnapshot.visibleReasoningSummaries,
                fileChangeAttributions: turnSnapshot.fileChangeAttributions,
                intent: semanticField(
                    kind: ProvenanceCodingAgentSemanticInferenceKind.turnIntent.rawValue,
                    scope: .turn,
                    scopeID: turnSnapshot.turn.id
                ),
                currentActivity: semanticField(
                    kind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
                    scope: .turn,
                    scopeID: turnSnapshot.turn.id,
                    record: currentActivityRecord
                )
            ),
            priorTurns: factualProjection.priorTurns,
            sessionPhase: semanticField(
                kind: ProvenanceCodingAgentSemanticInferenceKind.sessionPhase.rawValue,
                scope: .session,
                scopeID: sessionID,
                record: phaseRecord
            ),
            basis: ProvenanceSessionWorkModelBasis(
                factualSessionProjection: factualProjection,
                semanticInferenceRecords: semanticRecords
            )
        )
    }

    private static func semanticField(
        kind: String,
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String,
        record: ProvenanceSemanticInferenceRecord? = nil
    ) -> ProvenanceSessionWorkModelSemanticField {
        ProvenanceSessionWorkModelSemanticField(
            kind: kind,
            scope: scope,
            scopeID: scopeID,
            state: record == nil ? .unknown : .known,
            record: record.map(ProvenanceSessionWorkModelSemanticRecord.init(record:)),
            reason: record == nil ? "no_active_semantic_inference" : nil
        )
    }

    private static func semanticRecord(
        id: String,
        kind: String,
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String,
        payload: ProvenanceSemanticPayloadValue,
        factualRevision: Int,
        createdAt: Date
    ) -> ProvenanceSemanticInferenceRecord {
        ProvenanceSemanticInferenceRecord(
            id: id,
            kind: kind,
            scope: scope,
            scopeID: scopeID,
            payload: payload,
            supportingEvidenceRefs: [
                ProvenanceSemanticEvidenceReference(
                    kind: "factual_session_projection",
                    id: "session-1",
                    factualRevision: factualRevision
                )
            ],
            supportingFactualRevision: factualRevision,
            confidence: .medium,
            specificity: .granular,
            producerType: .rule,
            producerID: "test",
            producerVersion: "v1",
            createdAt: createdAt
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
