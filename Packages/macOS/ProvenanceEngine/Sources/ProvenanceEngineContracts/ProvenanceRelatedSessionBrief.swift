import Foundation

/// Compact evidence-backed brief for one session related to a target session.
public struct ProvenanceRelatedSessionBrief: Codable, Equatable, Sendable {
    /// Stable Provenance Engine session identifier.
    public let sessionID: String

    /// Current-state session projection record.
    public let session: ProvenanceSessionRecord

    /// Provider or runtime identities explicitly linked to the session.
    public let externalIdentities: [ProvenanceExternalIdentityRecord]

    /// Provider thread identities explicitly observed for the session.
    public let providerThreadIdentities: [ProvenanceFactualSessionProjectionProviderThreadIdentity]

    /// Repository, worktree, branch, and HEAD boundaries observed for the session.
    public let repositoryBoundaries: [ProvenanceSessionOutcomeRepositoryBoundary]

    /// Repository, worktree, branch, and HEAD boundaries with related-session evidence references.
    public let worktreeBoundaries: [ProvenanceRelatedSessionWorktreeBoundary]

    /// Session lifecycle state copied from accepted session projection state.
    public let lifecycleState: String

    /// Session completion state copied from Session Outcome.
    public let completionState: String

    /// Exact Session Outcome revision used for this brief, when available.
    public let sessionOutcomeRevisionID: String?

    /// Exact Session Outcome projection metadata used for this brief, when available.
    public let sessionOutcomeProjection: ProvenanceSessionOutcomeProjectionMetadata?

    /// Compact factual outcome brief derived from Session Outcome.
    public let outcomeBrief: ProvenanceRelatedSessionOutcomeBrief?

    /// Individually inspectable typed reasons for this relationship.
    public let relationshipReasons: [ProvenanceRelatedSessionRelationshipReason]

    /// Freshness metadata for this relationship and brief.
    public let freshness: ProvenanceRelatedSessionFreshness

    /// Existing SessionWorkModel semantic fields preserved with their semantic provenance.
    public let semanticFields: [ProvenanceSessionWorkModelSemanticField]

    /// Exact SessionWorkModel revision used for semantic fields, when available.
    public let sessionWorkModelRevision: ProvenanceSessionWorkModelRevision?

    /// Supporting evidence and projection references for this brief.
    public let evidence: [ProvenanceRelatedSessionEvidenceReference]

    /// Completeness state for this brief.
    public let completeness: ProvenanceRelatedSessionCompleteness

    /// Creates a related-session brief.
    public init(
        sessionID: String,
        session: ProvenanceSessionRecord,
        externalIdentities: [ProvenanceExternalIdentityRecord],
        providerThreadIdentities: [ProvenanceFactualSessionProjectionProviderThreadIdentity],
        repositoryBoundaries: [ProvenanceSessionOutcomeRepositoryBoundary],
        worktreeBoundaries: [ProvenanceRelatedSessionWorktreeBoundary],
        lifecycleState: String,
        completionState: String,
        sessionOutcomeRevisionID: String?,
        sessionOutcomeProjection: ProvenanceSessionOutcomeProjectionMetadata?,
        outcomeBrief: ProvenanceRelatedSessionOutcomeBrief?,
        relationshipReasons: [ProvenanceRelatedSessionRelationshipReason],
        freshness: ProvenanceRelatedSessionFreshness,
        semanticFields: [ProvenanceSessionWorkModelSemanticField],
        sessionWorkModelRevision: ProvenanceSessionWorkModelRevision?,
        evidence: [ProvenanceRelatedSessionEvidenceReference],
        completeness: ProvenanceRelatedSessionCompleteness
    ) {
        self.sessionID = sessionID
        self.session = session
        self.externalIdentities = externalIdentities
        self.providerThreadIdentities = providerThreadIdentities
        self.repositoryBoundaries = repositoryBoundaries
        self.worktreeBoundaries = worktreeBoundaries
        self.lifecycleState = lifecycleState
        self.completionState = completionState
        self.sessionOutcomeRevisionID = sessionOutcomeRevisionID
        self.sessionOutcomeProjection = sessionOutcomeProjection
        self.outcomeBrief = outcomeBrief
        self.relationshipReasons = relationshipReasons
        self.freshness = freshness
        self.semanticFields = semanticFields
        self.sessionWorkModelRevision = sessionWorkModelRevision
        self.evidence = evidence
        self.completeness = completeness
    }
}
