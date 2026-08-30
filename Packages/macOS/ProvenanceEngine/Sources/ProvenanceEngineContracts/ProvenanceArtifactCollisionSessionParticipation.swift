import Foundation

/// One session's participation in an artifact-collision candidate.
public struct ProvenanceArtifactCollisionSessionParticipation: Codable, Equatable, Sendable, Identifiable {
    /// Stable participation identifier.
    public let id: String

    /// Participating Provenance Engine session identifier.
    public let sessionID: String

    /// Current-state session projection record.
    public let session: ProvenanceSessionRecord

    /// Raw lifecycle state from the session projection.
    public let lifecycleState: String

    /// Normalized completion state from Session Outcome or lifecycle status.
    public let completionState: String

    /// Exact Session Outcome revision used for this participant, when available.
    public let sessionOutcomeRevisionID: String?

    /// Session Outcome projection metadata used for this participant, when available.
    public let sessionOutcomeProjection: ProvenanceSessionOutcomeProjectionMetadata?

    /// Matched changed artifact facts for this participant.
    public let matchedArtifacts: [ProvenanceSessionOutcomeArtifact]

    /// Repository boundaries observed by Session Outcome.
    public let repositoryBoundaries: [ProvenanceSessionOutcomeRepositoryBoundary]

    /// Worktree boundaries used by the related-session projection.
    public let worktreeBoundaries: [ProvenanceRelatedSessionWorktreeBoundary]

    /// Earliest observed changed time for the matched artifact facts.
    public let firstObservedChangedAt: Date?

    /// Latest observed changed time for the matched artifact facts.
    public let lastObservedChangedAt: Date?

    /// Evidence references supporting this participation.
    public let evidence: [ProvenanceArtifactCollisionEvidenceReference]

    /// Completeness state for this participation.
    public let completeness: ProvenanceArtifactCollisionCompleteness

    /// Creates one session participation record.
    public init(
        id: String,
        sessionID: String,
        session: ProvenanceSessionRecord,
        lifecycleState: String,
        completionState: String,
        sessionOutcomeRevisionID: String?,
        sessionOutcomeProjection: ProvenanceSessionOutcomeProjectionMetadata?,
        matchedArtifacts: [ProvenanceSessionOutcomeArtifact],
        repositoryBoundaries: [ProvenanceSessionOutcomeRepositoryBoundary],
        worktreeBoundaries: [ProvenanceRelatedSessionWorktreeBoundary],
        firstObservedChangedAt: Date?,
        lastObservedChangedAt: Date?,
        evidence: [ProvenanceArtifactCollisionEvidenceReference],
        completeness: ProvenanceArtifactCollisionCompleteness
    ) {
        self.id = id
        self.sessionID = sessionID
        self.session = session
        self.lifecycleState = lifecycleState
        self.completionState = completionState
        self.sessionOutcomeRevisionID = sessionOutcomeRevisionID
        self.sessionOutcomeProjection = sessionOutcomeProjection
        self.matchedArtifacts = matchedArtifacts
        self.repositoryBoundaries = repositoryBoundaries
        self.worktreeBoundaries = worktreeBoundaries
        self.firstObservedChangedAt = firstObservedChangedAt
        self.lastObservedChangedAt = lastObservedChangedAt
        self.evidence = evidence
        self.completeness = completeness
    }
}
