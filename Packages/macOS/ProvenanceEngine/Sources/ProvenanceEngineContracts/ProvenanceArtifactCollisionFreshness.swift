import Foundation

/// Freshness metadata for one artifact-collision candidate.
public struct ProvenanceArtifactCollisionFreshness: Codable, Equatable, Sendable {
    /// Candidate state derived from deterministic freshness and completeness rules.
    public let state: ProvenanceArtifactCollisionState

    /// Latest artifact-change observation across the candidate participants.
    public let latestArtifactObservedAt: Date?

    /// Optional request boundary used to classify stale candidates.
    public let staleBefore: Date?

    /// Latest accepted event sequence evaluated by this projection.
    public let sourceEvidenceWatermark: Int?

    /// Related-session projection revision used for candidate discovery.
    public let relatedSessionProjectionRevisionID: String?

    /// Related-session projection watermark used for candidate discovery.
    public let relatedSessionProjectionWatermark: Int?

    /// Creates candidate freshness metadata.
    public init(
        state: ProvenanceArtifactCollisionState,
        latestArtifactObservedAt: Date?,
        staleBefore: Date?,
        sourceEvidenceWatermark: Int?,
        relatedSessionProjectionRevisionID: String?,
        relatedSessionProjectionWatermark: Int?
    ) {
        self.state = state
        self.latestArtifactObservedAt = latestArtifactObservedAt
        self.staleBefore = staleBefore
        self.sourceEvidenceWatermark = sourceEvidenceWatermark
        self.relatedSessionProjectionRevisionID = relatedSessionProjectionRevisionID
        self.relatedSessionProjectionWatermark = relatedSessionProjectionWatermark
    }
}
