import Foundation

/// Contract-shaped client for authoritative Provenance Engine operations.
public protocol ProvenanceEngineClient: ProvenanceEngineHealthChecking {
    /// Appends one immutable provenance event.
    ///
    /// - Parameter request: Event append request.
    /// - Returns: Response describing the accepted event.
    /// - Throws: An implementation-defined error when append fails.
    func appendEvent(_ request: ProvenanceAppendEventRequest) async throws -> ProvenanceAppendEventResponse

    /// Records one normalized session lifecycle transition.
    ///
    /// - Parameter request: Normalized lifecycle request supplied by a client adapter.
    /// - Returns: Bounded response describing the accepted event or persistence failure.
    func recordSessionLifecycle(
        _ request: ProvenanceSessionLifecycleRequest
    ) async -> ProvenanceSessionLifecycleResponse

    /// Returns a bounded session tree rooted at the requested session.
    ///
    /// - Parameter request: Query parameters for the requested session tree.
    /// - Returns: A domain response containing sessions, relationships, and identities.
    /// - Throws: An implementation-defined error when the query fails.
    func sessionTree(_ request: ProvenanceSessionTreeRequest) async throws -> ProvenanceSessionTreeResponse

    /// Returns focused provenance context for a repository-relative file path.
    ///
    /// - Parameter request: File explanation query parameters.
    /// - Returns: A bounded file-explanation response.
    /// - Throws: An implementation-defined error when the query fails.
    func fileExplanation(_ request: ProvenanceFileExplanationRequest) async throws -> ProvenanceFileExplanationResponse

    /// Returns provenance worktrees in current-state query order.
    ///
    /// - Parameter request: Query parameters for the worktree list.
    /// - Returns: A domain response containing worktrees and linked repositories.
    /// - Throws: An implementation-defined error when the query fails.
    func worktrees(_ request: ProvenanceWorktreeListRequest) async throws -> ProvenanceWorktreeListResponse

    /// Returns the bounded current provenance context for one Git worktree.
    ///
    /// - Parameter request: Query parameters for the current context.
    /// - Returns: A domain response containing current worktree, session, file, and validation context.
    /// - Throws: An implementation-defined error when the query fails.
    func currentContext(_ request: ProvenanceCurrentContextRequest) async throws
        -> ProvenanceCurrentContextResponse

    /// Returns current display metadata for one workspace.
    ///
    /// - Parameter request: Query parameters for the workspace display projection.
    /// - Returns: A domain response containing the current workspace display projection.
    /// - Throws: An implementation-defined error when the query fails.
    func workspaceDisplay(_ request: ProvenanceWorkspaceDisplayRequest) async throws
        -> ProvenanceWorkspaceDisplayResponse

    /// Returns the factual session projection snapshot for one coding-agent session.
    ///
    /// - Parameter request: Query parameters for the factual session projection.
    /// - Returns: A revisioned response containing observed thread and turn evidence.
    /// - Throws: An implementation-defined error when the query fails.
    func factualSessionProjection(_ request: ProvenanceFactualSessionProjectionRequest) async throws
        -> ProvenanceFactualSessionProjectionResponse

    /// Returns factual detail for one observed coding-agent turn.
    ///
    /// - Parameter request: Query parameters for the factual turn detail.
    /// - Returns: A revisioned response containing observed evidence linked to the turn.
    /// - Throws: An implementation-defined error when the query fails.
    func factualSessionTurnDetail(_ request: ProvenanceFactualSessionTurnDetailRequest) async throws
        -> ProvenanceFactualSessionTurnDetailResponse

    /// Returns the deterministic factual outcome projection for one observed coding-agent turn.
    ///
    /// - Parameter request: Query parameters for the turn outcome.
    /// - Returns: A revisioned response containing evidence-backed outcome facts for the turn.
    /// - Throws: An implementation-defined error when the query fails.
    func turnOutcome(_ request: ProvenanceTurnOutcomeRequest) async throws
        -> ProvenanceTurnOutcomeResponse

    /// Returns the deterministic factual outcome projection for one observed coding-agent session.
    ///
    /// - Parameter request: Query parameters for the session outcome.
    /// - Returns: A revisioned response containing evidence-backed outcome facts for the session.
    /// - Throws: An implementation-defined error when the query fails.
    func sessionOutcome(_ request: ProvenanceSessionOutcomeRequest) async throws
        -> ProvenanceSessionOutcomeResponse

    /// Returns the PE-owned deterministic related-session projection for one coding-agent session.
    ///
    /// - Parameter request: Query parameters for the related-session read.
    /// - Returns: A bounded response containing evidence-backed related-session briefs.
    /// - Throws: An implementation-defined error when the query fails.
    func relatedSessions(_ request: ProvenanceRelatedSessionRequest) async throws
        -> ProvenanceRelatedSessionResponse

    /// Returns PE-owned deterministic artifact-collision awareness for one target session.
    ///
    /// - Parameter request: Query parameters for the artifact-collision read.
    /// - Returns: A bounded response containing evidence-backed possible collision candidates.
    /// - Throws: An implementation-defined error when the query fails.
    func artifactCollisions(_ request: ProvenanceArtifactCollisionRequest) async throws
        -> ProvenanceArtifactCollisionResponse

    /// Publishes one semantic inference record above deterministic Current State.
    ///
    /// - Parameter request: Semantic inference record to publish.
    /// - Returns: Response describing the accepted inference and superseded history.
    /// - Throws: An implementation-defined error when publishing fails.
    func publishSemanticInference(_ request: ProvenanceSemanticInferencePublishRequest) async throws
        -> ProvenanceSemanticInferencePublishResponse

    /// Returns semantic inference records for one scoped subject.
    ///
    /// - Parameter request: Query parameters for semantic inference records.
    /// - Returns: Versioned semantic inference records matching the query.
    /// - Throws: An implementation-defined error when the query fails.
    func semanticInferences(_ request: ProvenanceSemanticInferenceQueryRequest) async throws
        -> ProvenanceSemanticInferenceQueryResponse

    /// Publishes one human-readable semantic message record above semantic inference truth.
    ///
    /// - Parameter request: Semantic message record to publish.
    /// - Returns: Response describing the accepted message and superseded wording history.
    /// - Throws: An implementation-defined error when publishing fails.
    func publishSemanticMessage(_ request: ProvenanceSemanticMessagePublishRequest) async throws
        -> ProvenanceSemanticMessagePublishResponse

    /// Returns human-readable semantic message records for one scoped subject.
    ///
    /// - Parameter request: Query parameters for semantic message records.
    /// - Returns: Versioned semantic messages matching the query.
    /// - Throws: An implementation-defined error when the query fails.
    func semanticMessages(_ request: ProvenanceSemanticMessageQueryRequest) async throws
        -> ProvenanceSemanticMessageQueryResponse

    /// Materializes cached semantic messages from semantic inference records.
    ///
    /// - Parameter request: Semantic inference records and presentation policy to render.
    /// - Returns: Message records published, retained, or skipped by this pass.
    /// - Throws: An implementation-defined error when semantic reads or writes fail.
    func materializeSemanticMessages(_ request: ProvenanceSemanticMessageMaterializationRequest) async throws
        -> ProvenanceSemanticMessageMaterializationResponse

    /// Materializes first-pass coding-agent semantic inferences from factual session evidence.
    ///
    /// - Parameter request: Query/producer parameters for one PE session.
    /// - Returns: Records published or retained by the inference pass.
    /// - Throws: An implementation-defined error when factual reads, semantic reads, or semantic writes fail.
    func publishCodingAgentSessionSemanticInferences(
        _ request: ProvenanceCodingAgentSessionSemanticInferenceRequest
    ) async throws -> ProvenanceCodingAgentSessionSemanticInferenceResponse

    /// Returns the PE-owned factual plus semantic work model for one coding-agent session.
    ///
    /// - Parameter request: Query parameters for the SessionWorkModel snapshot.
    /// - Returns: A revisioned response containing the coherent session-understanding model.
    /// - Throws: An implementation-defined error when the query fails.
    func sessionWorkModel(_ request: ProvenanceSessionWorkModelRequest) async throws
        -> ProvenanceSessionWorkModelResponse
}

public extension ProvenanceEngineClient {
    /// Records one normalized child-session lifecycle transition.
    ///
    /// - Parameter request: Normalized lifecycle request supplied by a client adapter.
    /// - Returns: Bounded response describing the accepted event or persistence failure.
    @available(*, deprecated, renamed: "recordSessionLifecycle")
    func recordSubsessionLifecycle(
        _ request: ProvenanceSubsessionLifecycleRequest
    ) async -> ProvenanceSubsessionLifecycleResponse {
        await recordSessionLifecycle(request.sessionLifecycleRequest).subsessionLifecycleResponse
    }

    /// Default unsupported response for clients that have not adopted factual turn-detail reads.
    func factualSessionTurnDetail(_ request: ProvenanceFactualSessionTurnDetailRequest) async throws
        -> ProvenanceFactualSessionTurnDetailResponse {
        ProvenanceFactualSessionTurnDetailResponse(
            found: false,
            reason: "unsupported",
            turnID: request.turnID,
            turnDetail: nil
        )
    }

    /// Default unsupported response for clients that have not adopted turn-outcome reads.
    func turnOutcome(_ request: ProvenanceTurnOutcomeRequest) async throws
        -> ProvenanceTurnOutcomeResponse {
        ProvenanceTurnOutcomeResponse(
            found: false,
            reason: "unsupported",
            turnID: request.turnID,
            outcome: nil
        )
    }

    /// Default unsupported response for clients that have not adopted session-outcome reads.
    func sessionOutcome(_ request: ProvenanceSessionOutcomeRequest) async throws
        -> ProvenanceSessionOutcomeResponse {
        ProvenanceSessionOutcomeResponse(
            found: false,
            reason: "unsupported",
            sessionID: request.sessionID,
            outcome: nil
        )
    }

    /// Default unsupported response for clients that have not adopted related-session reads.
    func relatedSessions(_ request: ProvenanceRelatedSessionRequest) async throws
        -> ProvenanceRelatedSessionResponse {
        ProvenanceRelatedSessionResponse(
            found: false,
            reason: "unsupported",
            targetSessionID: request.targetSessionID,
            projection: nil
        )
    }

    /// Default unsupported response for clients that have not adopted artifact-collision awareness reads.
    func artifactCollisions(_ request: ProvenanceArtifactCollisionRequest) async throws
        -> ProvenanceArtifactCollisionResponse {
        ProvenanceArtifactCollisionResponse(
            found: false,
            reason: "unsupported",
            targetSessionID: request.targetSessionID,
            projection: nil
        )
    }

    /// Default unsupported response for clients that have not adopted semantic inference publishing.
    func publishSemanticInference(_ request: ProvenanceSemanticInferencePublishRequest) async throws
        -> ProvenanceSemanticInferencePublishResponse {
        ProvenanceSemanticInferencePublishResponse(
            accepted: false,
            inferenceID: request.record.id,
            supersededInferenceIDs: []
        )
    }

    /// Default empty response for clients that have not adopted semantic inference reads.
    func semanticInferences(_ request: ProvenanceSemanticInferenceQueryRequest) async throws
        -> ProvenanceSemanticInferenceQueryResponse {
        ProvenanceSemanticInferenceQueryResponse(records: [])
    }

    /// Default unsupported response for clients that have not adopted SessionWorkModel reads.
    func sessionWorkModel(_ request: ProvenanceSessionWorkModelRequest) async throws
        -> ProvenanceSessionWorkModelResponse {
        ProvenanceSessionWorkModelResponse(
            found: false,
            reason: "unsupported",
            sessionID: request.sessionID,
            model: nil
        )
    }
}
