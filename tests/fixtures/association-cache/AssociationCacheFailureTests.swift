import Foundation
import ProvenanceEngineContracts
import Testing
@testable import Store

@Suite @MainActor
struct AssociationCacheFailureTests {
    @Test func notFoundThenFailureDoesNotResurrectPreviousBinding() async {
        let workspace = UUID()
        let association = Self.association(workspace: workspace, session: "session-a")
        let available = Self.readiness(workspace: workspace, status: .available, session: "session-a")
        let absent = Self.readiness(workspace: workspace, status: .noSupportedCodingAgentDetected, session: nil)
        let client = FakeProvenanceEngineClient()
        await client.setAssociationResults([
            .success(.init(found: true, workspaceID: workspace.uuidString, agentKind: "codex", association: association, readiness: available)),
            .success(.init(found: false, workspaceID: workspace.uuidString, agentKind: "codex", association: nil, readiness: absent)),
            .failure(TestError.unavailable)
        ])
        let store = WorkspaceCodingAgentSessionAssociationStore(client: client)
        #expect(await store.refreshedAssociation(stableWorkspaceID: workspace) == .available(association, available))
        #expect(await store.refreshedAssociation(stableWorkspaceID: workspace) == .notFound(absent))
        guard case .failed(let failure) = await store.refreshedAssociation(stableWorkspaceID: workspace) else {
            Issue.record("Failed read resurrected an association after authoritative not-found")
            return
        }
        #expect(failure.workspaceID == workspace.uuidString)
        #expect(failure.reasonCode == "association_read_failed")
    }

    @Test func failedRefreshDoesNotMarkOldBindingCurrent() async {
        let workspace = UUID()
        let association = Self.association(workspace: workspace, session: "session-a")
        let readiness = Self.readiness(workspace: workspace, status: .available, session: "session-a")
        let client = FakeProvenanceEngineClient()
        await client.setAssociationResults([
            .success(.init(found: true, workspaceID: workspace.uuidString, agentKind: "codex", association: association, readiness: readiness)),
            .failure(TestError.unavailable)
        ])
        let store = WorkspaceCodingAgentSessionAssociationStore(client: client)
        #expect(await store.refreshedAssociation(stableWorkspaceID: workspace) == .available(association, readiness))
        guard case .failed(let failure) = await store.refreshedAssociation(stableWorkspaceID: workspace) else {
            Issue.record("Failed read returned the old association as available")
            return
        }
        #expect(failure.workspaceID == workspace.uuidString)
        #expect(failure.reasonCode == "association_read_failed")
    }

    @Test func failureInAnotherWorkspaceDoesNotReuseFirstBinding() async {
        let first = UUID()
        let second = UUID()
        let association = Self.association(workspace: first, session: "session-a")
        let readiness = Self.readiness(workspace: first, status: .available, session: "session-a")
        let client = FakeProvenanceEngineClient()
        await client.setAssociationResults([
            .success(.init(found: true, workspaceID: first.uuidString, agentKind: "codex", association: association, readiness: readiness)),
            .failure(TestError.unavailable)
        ])
        let store = WorkspaceCodingAgentSessionAssociationStore(client: client)
        #expect(await store.refreshedAssociation(stableWorkspaceID: first) == .available(association, readiness))
        guard case .failed(let failure) = await store.refreshedAssociation(stableWorkspaceID: second) else {
            Issue.record("Another workspace reused the first workspace binding")
            return
        }
        #expect(failure.workspaceID == second.uuidString)
    }

    private static func association(workspace: UUID, session: String) -> ProvenanceWorkspaceCodingAgentSessionAssociationRecord {
        let time = Date(timeIntervalSince1970: 100)
        return .init(id: "association", workspaceID: workspace.uuidString, sessionID: session, agentKind: "codex", sourcePath: "fixture", stage: "available", firstObservedAt: time, lastObservedAt: time, lastTransitionAt: time)
    }

    private static func readiness(workspace: UUID, status: ProvenanceWorkspaceCodingAgentSessionReadinessStatus, session: String?) -> ProvenanceWorkspaceCodingAgentSessionReadiness {
        .init(status: status, workspaceID: workspace.uuidString, agentKind: "codex", sessionID: session, stage: "fixture", reasonCode: nil, retryable: true)
    }
}

private actor FakeProvenanceEngineClient: ProvenanceEngineClient {
    private var associationResults: [Result<ProvenanceWorkspaceCodingAgentSessionAssociationResponse, Error>] = []
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

    func setAssociationResults(_ results: [Result<ProvenanceWorkspaceCodingAgentSessionAssociationResponse, Error>]) {
        associationResults = results
    }

    func workspaceCodingAgentSessionAssociation(_ request: ProvenanceWorkspaceCodingAgentSessionAssociationRequest) async throws -> ProvenanceWorkspaceCodingAgentSessionAssociationResponse {
        guard !associationResults.isEmpty else { throw TestError.unimplemented }
        return try associationResults.removeFirst().get()
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
