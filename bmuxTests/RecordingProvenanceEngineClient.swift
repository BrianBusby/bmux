import ProvenanceEngineContracts

/// Records append requests while delegating storage to the supplied client.
actor RecordingProvenanceEngineClient: ProvenanceEngineContracts.ProvenanceEngineClient {
    private let backing: any ProvenanceEngineContracts.ProvenanceEngineClient
    private var events: [ProvenanceEngineContracts.ProvenanceEvent] = []

    init(backing: any ProvenanceEngineContracts.ProvenanceEngineClient) {
        self.backing = backing
    }

    func appendedEvents() -> [ProvenanceEngineContracts.ProvenanceEvent] {
        events
    }

    func health() async throws -> ProvenanceEngineContracts.ProvenanceEngineHealth {
        try await backing.health()
    }

    func appendEvent(
        _ request: ProvenanceEngineContracts.ProvenanceAppendEventRequest
    ) async throws -> ProvenanceEngineContracts.ProvenanceAppendEventResponse {
        events.append(request.event)
        return try await backing.appendEvent(request)
    }

    func recordSessionLifecycle(
        _ request: ProvenanceEngineContracts.ProvenanceSessionLifecycleRequest
    ) async -> ProvenanceEngineContracts.ProvenanceSessionLifecycleResponse {
        await backing.recordSessionLifecycle(request)
    }

    func sessionTree(
        _ request: ProvenanceEngineContracts.ProvenanceSessionTreeRequest
    ) async throws -> ProvenanceEngineContracts.ProvenanceSessionTreeResponse {
        try await backing.sessionTree(request)
    }

    func fileExplanation(
        _ request: ProvenanceEngineContracts.ProvenanceFileExplanationRequest
    ) async throws -> ProvenanceEngineContracts.ProvenanceFileExplanationResponse {
        try await backing.fileExplanation(request)
    }

    func worktrees(
        _ request: ProvenanceEngineContracts.ProvenanceWorktreeListRequest
    ) async throws -> ProvenanceEngineContracts.ProvenanceWorktreeListResponse {
        try await backing.worktrees(request)
    }

    func currentContext(
        _ request: ProvenanceEngineContracts.ProvenanceCurrentContextRequest
    ) async throws -> ProvenanceEngineContracts.ProvenanceCurrentContextResponse {
        try await backing.currentContext(request)
    }

    func workspaceDisplay(
        _ request: ProvenanceEngineContracts.ProvenanceWorkspaceDisplayRequest
    ) async throws -> ProvenanceEngineContracts.ProvenanceWorkspaceDisplayResponse {
        try await backing.workspaceDisplay(request)
    }

    func factualSessionProjection(
        _ request: ProvenanceEngineContracts.ProvenanceFactualSessionProjectionRequest
    ) async throws -> ProvenanceEngineContracts.ProvenanceFactualSessionProjectionResponse {
        try await backing.factualSessionProjection(request)
    }
}
