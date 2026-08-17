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
        let client = RefreshCoalescingProvenanceEngineClient(model: Self.model(sessionID: "session-1"))
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

    private static func model(sessionID: String) -> ProvenanceSessionWorkModel {
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
            revision: 42,
            session: session,
            providerThreads: [],
            turns: []
        )
        return ProvenanceSessionWorkModel(
            revision: ProvenanceSessionWorkModelRevision(
                factualRevision: 42,
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
}

private enum RefreshCoalescingTestError: Error {
    case unimplemented
}

private actor RefreshCoalescingProvenanceEngineClient: ProvenanceEngineClient {
    private let model: ProvenanceSessionWorkModel
    private var publishRequests: [ProvenanceCodingAgentSessionSemanticInferenceRequest] = []
    private var workModelRequests: [ProvenanceSessionWorkModelRequest] = []
    private var publishStartedContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuations: [CheckedContinuation<Void, Never>] = []
    private var isPublishReleased = false

    init(model: ProvenanceSessionWorkModel) {
        self.model = model
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
        throw RefreshCoalescingTestError.unimplemented
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
        throw RefreshCoalescingTestError.unimplemented
    }

    func fileExplanation(_ request: ProvenanceFileExplanationRequest) async throws -> ProvenanceFileExplanationResponse {
        throw RefreshCoalescingTestError.unimplemented
    }

    func worktrees(_ request: ProvenanceWorktreeListRequest) async throws -> ProvenanceWorktreeListResponse {
        throw RefreshCoalescingTestError.unimplemented
    }

    func currentContext(
        _ request: ProvenanceEngineContracts.ProvenanceCurrentContextRequest
    ) async throws -> ProvenanceEngineContracts.ProvenanceCurrentContextResponse {
        throw RefreshCoalescingTestError.unimplemented
    }

    func workspaceDisplay(_ request: ProvenanceWorkspaceDisplayRequest) async throws -> ProvenanceWorkspaceDisplayResponse {
        throw RefreshCoalescingTestError.unimplemented
    }

    func factualSessionProjection(
        _ request: ProvenanceFactualSessionProjectionRequest
    ) async throws -> ProvenanceFactualSessionProjectionResponse {
        throw RefreshCoalescingTestError.unimplemented
    }

    func sessionWorkModel(_ request: ProvenanceSessionWorkModelRequest) async throws -> ProvenanceSessionWorkModelResponse {
        workModelRequests.append(request)
        return ProvenanceSessionWorkModelResponse(found: true, sessionID: request.sessionID, model: model)
    }

    func publishSemanticMessage(
        _ request: ProvenanceSemanticMessagePublishRequest
    ) async throws -> ProvenanceSemanticMessagePublishResponse {
        throw RefreshCoalescingTestError.unimplemented
    }

    func semanticMessages(
        _ request: ProvenanceSemanticMessageQueryRequest
    ) async throws -> ProvenanceSemanticMessageQueryResponse {
        ProvenanceSemanticMessageQueryResponse(records: [])
    }

    func materializeSemanticMessages(
        _ request: ProvenanceSemanticMessageMaterializationRequest
    ) async throws -> ProvenanceSemanticMessageMaterializationResponse {
        throw RefreshCoalescingTestError.unimplemented
    }

    func publishCodingAgentSessionSemanticInferences(
        _ request: ProvenanceCodingAgentSessionSemanticInferenceRequest
    ) async throws -> ProvenanceCodingAgentSessionSemanticInferenceResponse {
        publishRequests.append(request)
        publishStartedContinuation?.resume()
        publishStartedContinuation = nil
        if !isPublishReleased {
            await withCheckedContinuation { continuation in
                releaseContinuations.append(continuation)
            }
        }
        return ProvenanceCodingAgentSessionSemanticInferenceResponse(
            found: true,
            sessionID: request.sessionID,
            factualRevision: model.revision.factualRevision
        )
    }
}
