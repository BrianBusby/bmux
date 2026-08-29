/// One bounded, explainable possible artifact collision candidate.
public struct ProvenanceArtifactCollisionCandidate: Codable, Equatable, Sendable, Identifiable {
    /// Stable candidate identifier for this projection rule and participant set.
    public let id: String

    /// Candidate factual state.
    public let state: ProvenanceArtifactCollisionState

    /// Artifact identity used by candidate discovery.
    public let artifactIdentity: ProvenanceArtifactCollisionArtifactIdentity

    /// Path boundary and supported relationship semantics.
    public let pathBoundary: ProvenanceArtifactCollisionPathBoundary

    /// Participating sessions that touched the artifact.
    public let participants: [ProvenanceArtifactCollisionSessionParticipation]

    /// Repository, worktree, branch, and HEAD comparison across participants.
    public let boundaryComparison: ProvenanceArtifactCollisionBoundaryComparison

    /// Temporal relationship between participating artifact observations.
    public let temporalOverlap: ProvenanceArtifactCollisionTemporalOverlap

    /// Typed factual reasons for returning this candidate.
    public let reasons: [ProvenanceArtifactCollisionReason]

    /// Freshness and stale-state metadata.
    public let freshness: ProvenanceArtifactCollisionFreshness

    /// Evidence and projection references supporting the candidate.
    public let evidence: [ProvenanceArtifactCollisionEvidenceReference]

    /// Completeness state for this candidate.
    public let completeness: ProvenanceArtifactCollisionCompleteness

    /// Bounded explanatory notes about projection limits and non-goals.
    public let notes: [String]

    /// Creates an artifact-collision candidate.
    public init(
        id: String,
        state: ProvenanceArtifactCollisionState,
        artifactIdentity: ProvenanceArtifactCollisionArtifactIdentity,
        pathBoundary: ProvenanceArtifactCollisionPathBoundary,
        participants: [ProvenanceArtifactCollisionSessionParticipation],
        boundaryComparison: ProvenanceArtifactCollisionBoundaryComparison,
        temporalOverlap: ProvenanceArtifactCollisionTemporalOverlap,
        reasons: [ProvenanceArtifactCollisionReason],
        freshness: ProvenanceArtifactCollisionFreshness,
        evidence: [ProvenanceArtifactCollisionEvidenceReference],
        completeness: ProvenanceArtifactCollisionCompleteness,
        notes: [String]
    ) {
        self.id = id
        self.state = state
        self.artifactIdentity = artifactIdentity
        self.pathBoundary = pathBoundary
        self.participants = participants
        self.boundaryComparison = boundaryComparison
        self.temporalOverlap = temporalOverlap
        self.reasons = reasons
        self.freshness = freshness
        self.evidence = evidence
        self.completeness = completeness
        self.notes = notes
    }
}
