/// Deterministic artifact-collision awareness projection for one target session.
public struct ProvenanceArtifactCollisionProjection: Codable, Equatable, Sendable {
    /// Schema version for this projection shape.
    public let schemaVersion: Int

    /// Provenance session identifier used as the collision-awareness target.
    public let targetSessionID: String

    /// Target session projection record.
    public let targetSession: ProvenanceSessionRecord

    /// Exact Session Outcome projection used for the target, when available.
    public let targetSessionOutcomeProjection: ProvenanceSessionOutcomeProjectionMetadata?

    /// Exact related-session projection used for candidate discovery, when available.
    public let relatedSessionProjection: ProvenanceRelatedSessionProjectionMetadata?

    /// Artifact-collision projection metadata.
    public let projection: ProvenanceArtifactCollisionProjectionMetadata

    /// Bounded possible-collision candidates in deterministic order.
    public let candidates: [ProvenanceArtifactCollisionCandidate]

    /// Bounded explanations for omitted candidates or unsupported relationships.
    public let excludedCandidates: [ProvenanceArtifactCollisionCandidateExclusion]

    /// Completeness state for this projection.
    public let completeness: ProvenanceArtifactCollisionCompleteness

    /// Creates an artifact-collision projection.
    public init(
        schemaVersion: Int = 1,
        targetSessionID: String,
        targetSession: ProvenanceSessionRecord,
        targetSessionOutcomeProjection: ProvenanceSessionOutcomeProjectionMetadata?,
        relatedSessionProjection: ProvenanceRelatedSessionProjectionMetadata?,
        projection: ProvenanceArtifactCollisionProjectionMetadata,
        candidates: [ProvenanceArtifactCollisionCandidate],
        excludedCandidates: [ProvenanceArtifactCollisionCandidateExclusion],
        completeness: ProvenanceArtifactCollisionCompleteness
    ) {
        self.schemaVersion = schemaVersion
        self.targetSessionID = targetSessionID
        self.targetSession = targetSession
        self.targetSessionOutcomeProjection = targetSessionOutcomeProjection
        self.relatedSessionProjection = relatedSessionProjection
        self.projection = projection
        self.candidates = candidates
        self.excludedCandidates = excludedCandidates
        self.completeness = completeness
    }
}
