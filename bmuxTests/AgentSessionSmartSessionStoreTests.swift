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
struct AgentSessionSmartSessionStoreTests {
    @Test
    func concurrentRefreshesForSameSessionShareRefreshTask() async {
        let client = SmartSessionStoreTestClient(
            model: Self.model(sessionID: "session-1", revision: 42),
            waitForRelease: true
        )
        let store = AgentSessionSmartSessionStore(client: client)

        async let firstResult = store.refreshedSnapshot(sessionID: "session-1")
        await client.waitForPublishStart()
        async let secondResult = store.refreshedSnapshot(sessionID: " session-1 ")
        for _ in 0..<10 {
            await Task.yield()
        }
        await client.releasePublish()

        let results = await (firstResult, secondResult)
        guard case let .available(firstSnapshot) = results.0,
              case let .available(secondSnapshot) = results.1 else {
            Issue.record("Expected both overlapping refreshes to return the available Smart Session snapshot")
            return
        }

        #expect(firstSnapshot.identity.sessionID == "session-1")
        #expect(secondSnapshot.revision.key == firstSnapshot.revision.key)
        #expect(await client.publishRequestCount() == 1)
        #expect(await client.sessionWorkModelRequestCount() == 1)
    }

    @Test
    func refreshRetriesWhenModelFactualRevisionAdvancesAfterMaterialization() async {
        let model = Self.model(sessionID: "session-1", revision: 43)
        let client = SmartSessionStoreTestClient(
            models: [model, model],
            materializedFactualRevisions: [42, 43]
        )
        let store = AgentSessionSmartSessionStore(client: client)

        guard case let .available(snapshot) = await store.refreshedSnapshot(sessionID: "session-1") else {
            Issue.record("Expected available Smart Session snapshot after retry")
            return
        }

        #expect(snapshot.revision.factualRevision == 43)
        #expect(await client.publishRequestCount() == 2)
        #expect(await client.sessionWorkModelRequestCount() == 2)
    }

    @Test
    func generatedCommandActivitySummariesAreLocalized() throws {
        let payload = ProvenanceCodingAgentCurrentActivityPayload(
            activityKind: .validation,
            summary: "Validating with swift test",
            action: "validate",
            subject: "current changes",
            basis: "completed_command"
        )
        let record = ProvenanceSessionWorkModelSemanticRecord(record: Self.semanticRecord(
            kind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
            scope: .turn,
            scopeID: "turn-1",
            payload: payload.semanticPayloadValue
        ))

        let summary = try #require(AgentSessionSmartSessionSnapshot.SemanticField.summary(
            kind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
            record: record
        ))

        #expect(summary == String(
            localized: "agentSession.web.smartSession.activitySummary.validatingCurrentChanges",
            defaultValue: "Validating current changes"
        ))
        #expect(summary != payload.summary)
        #expect(record.payload == payload.semanticPayloadValue)
    }

    private static func model(sessionID: String, revision: Int) -> ProvenanceSessionWorkModel {
        let updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let session = ProvenanceSessionRecord(
            id: sessionID,
            agentKind: "codex",
            workspaceID: "workspace-1",
            surfaceID: "surface-1",
            worktreeID: "worktree-1",
            cwd: "/repo",
            status: "active",
            startedAt: updatedAt,
            updatedAt: updatedAt
        )
        let factualProjection = ProvenanceFactualSessionProjectionSnapshot(
            revision: revision,
            session: session,
            providerThreads: [],
            turns: []
        )
        return ProvenanceSessionWorkModel(
            revision: ProvenanceSessionWorkModelRevision(
                factualRevision: revision,
                semanticInferenceIDs: [],
                latestSemanticInferenceCreatedAt: nil
            ),
            identity: ProvenanceSessionWorkModelIdentity(
                session: session,
                providerThreadIdentities: []
            ),
            thread: nil,
            currentTurn: nil,
            priorTurns: [],
            sessionPhase: ProvenanceSessionWorkModelSemanticField(
                kind: ProvenanceCodingAgentSemanticInferenceKind.sessionPhase.rawValue,
                scope: .session,
                scopeID: sessionID,
                state: .unknown,
                reason: "no_active_semantic_inference"
            ),
            basis: ProvenanceSessionWorkModelBasis(
                factualSessionProjection: factualProjection,
                semanticInferenceRecords: []
            )
        )
    }

    private static func semanticRecord(
        kind: String,
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String,
        payload: ProvenanceSemanticPayloadValue
    ) -> ProvenanceSemanticInferenceRecord {
        ProvenanceSemanticInferenceRecord(
            id: "inference-1",
            kind: kind,
            scope: scope,
            scopeID: scopeID,
            payload: payload,
            supportingEvidenceRefs: [
                ProvenanceSemanticEvidenceReference(
                    kind: "factual_session_projection",
                    id: "session-1",
                    factualRevision: 42
                )
            ],
            supportingFactualRevision: 42,
            confidence: .medium,
            specificity: .granular,
            producerType: .rule,
            producerID: "test",
            producerVersion: "v1",
            createdAt: Date(timeIntervalSince1970: 1_800_000_120)
        )
    }
}

private enum SmartSessionStoreTestError: Error {
    case unimplemented
}

private actor SmartSessionStoreTestClient: ProvenanceEngineClient {
    private let models: [ProvenanceSessionWorkModel]
    private let materializedFactualRevisions: [Int?]
    private var publishRequests: [ProvenanceCodingAgentSessionSemanticInferenceRequest] = []
    private var workModelRequests: [ProvenanceSessionWorkModelRequest] = []
    private var publishStartedContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuations: [CheckedContinuation<Void, Never>] = []
    private var isPublishReleased: Bool

    init(model: ProvenanceSessionWorkModel, waitForRelease: Bool = false) {
        self.init(
            models: [model],
            materializedFactualRevisions: [model.revision.factualRevision],
            waitForRelease: waitForRelease
        )
    }

    init(
        models: [ProvenanceSessionWorkModel],
        materializedFactualRevisions: [Int?],
        waitForRelease: Bool = false
    ) {
        self.models = models
        self.materializedFactualRevisions = materializedFactualRevisions
        self.isPublishReleased = !waitForRelease
    }

    func waitForPublishStart() async {
        guard publishRequests.isEmpty else { return }
        await withCheckedContinuation { continuation in
            publishStartedContinuation = continuation
        }
    }

    func releasePublish() {
        isPublishReleased = true
        let continuations = releaseContinuations
        releaseContinuations = []
        for continuation in continuations {
            continuation.resume()
        }
    }

    func publishRequestCount() -> Int {
        publishRequests.count
    }

    func sessionWorkModelRequestCount() -> Int {
        workModelRequests.count
    }

    func health() async throws -> ProvenanceEngineHealth {
        ProvenanceEngineHealth(status: .available, version: "test", capabilities: [])
    }

    func appendEvent(
        _ request: ProvenanceEngineContracts.ProvenanceAppendEventRequest
    ) async throws -> ProvenanceEngineContracts.ProvenanceAppendEventResponse {
        throw SmartSessionStoreTestError.unimplemented
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
        throw SmartSessionStoreTestError.unimplemented
    }

    func fileExplanation(_ request: ProvenanceFileExplanationRequest) async throws -> ProvenanceFileExplanationResponse {
        throw SmartSessionStoreTestError.unimplemented
    }

    func worktrees(_ request: ProvenanceWorktreeListRequest) async throws -> ProvenanceWorktreeListResponse {
        throw SmartSessionStoreTestError.unimplemented
    }

    func currentContext(
        _ request: ProvenanceEngineContracts.ProvenanceCurrentContextRequest
    ) async throws -> ProvenanceEngineContracts.ProvenanceCurrentContextResponse {
        throw SmartSessionStoreTestError.unimplemented
    }

    func workspaceDisplay(_ request: ProvenanceWorkspaceDisplayRequest) async throws -> ProvenanceWorkspaceDisplayResponse {
        throw SmartSessionStoreTestError.unimplemented
    }

    func factualSessionProjection(
        _ request: ProvenanceFactualSessionProjectionRequest
    ) async throws -> ProvenanceFactualSessionProjectionResponse {
        throw SmartSessionStoreTestError.unimplemented
    }

    func sessionWorkModel(_ request: ProvenanceSessionWorkModelRequest) async throws -> ProvenanceSessionWorkModelResponse {
        let index = workModelRequests.count
        workModelRequests.append(request)
        let model = models[min(index, models.count - 1)]
        return ProvenanceSessionWorkModelResponse(found: true, sessionID: request.sessionID, model: model)
    }

    func publishSemanticMessage(
        _ request: ProvenanceSemanticMessagePublishRequest
    ) async throws -> ProvenanceSemanticMessagePublishResponse {
        throw SmartSessionStoreTestError.unimplemented
    }

    func semanticMessages(
        _ request: ProvenanceSemanticMessageQueryRequest
    ) async throws -> ProvenanceSemanticMessageQueryResponse {
        ProvenanceSemanticMessageQueryResponse(records: [])
    }

    func materializeSemanticMessages(
        _ request: ProvenanceSemanticMessageMaterializationRequest
    ) async throws -> ProvenanceSemanticMessageMaterializationResponse {
        throw SmartSessionStoreTestError.unimplemented
    }

    func publishCodingAgentSessionSemanticInferences(
        _ request: ProvenanceCodingAgentSessionSemanticInferenceRequest
    ) async throws -> ProvenanceCodingAgentSessionSemanticInferenceResponse {
        let index = publishRequests.count
        publishRequests.append(request)
        publishStartedContinuation?.resume()
        publishStartedContinuation = nil
        if !isPublishReleased {
            await withCheckedContinuation { continuation in
                releaseContinuations.append(continuation)
            }
        }
        let factualRevision = materializedFactualRevisions[min(index, materializedFactualRevisions.count - 1)]
        return ProvenanceCodingAgentSessionSemanticInferenceResponse(
            found: true,
            sessionID: request.sessionID,
            factualRevision: factualRevision
        )
    }
}
