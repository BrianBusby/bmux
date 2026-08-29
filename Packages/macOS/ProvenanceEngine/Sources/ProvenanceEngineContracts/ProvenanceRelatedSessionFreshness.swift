import Foundation

/// Freshness metadata for one related-session brief.
public struct ProvenanceRelatedSessionFreshness: Codable, Equatable, Sendable {
    /// Latest event-ledger sequence evaluated for the relationship projection.
    public let relationshipEvidenceWatermark: Int?

    /// Timestamp of the latest relationship evidence, when known.
    public let relationshipObservedAt: Date?

    /// Deterministic generation timestamp for the Session Outcome brief.
    public let sessionOutcomeGeneratedAt: Date?

    /// Latest semantic inference timestamp used by SessionWorkModel, when present.
    public let sessionWorkModelLatestSemanticInferenceCreatedAt: Date?

    /// Deterministic generation timestamp for the related-session projection.
    public let projectionGeneratedAt: Date?

    /// Stable freshness state such as `available`, `partial`, or `unavailable`.
    public let state: String

    /// Creates related-session freshness metadata.
    public init(
        relationshipEvidenceWatermark: Int?,
        relationshipObservedAt: Date?,
        sessionOutcomeGeneratedAt: Date?,
        sessionWorkModelLatestSemanticInferenceCreatedAt: Date?,
        projectionGeneratedAt: Date?,
        state: String
    ) {
        self.relationshipEvidenceWatermark = relationshipEvidenceWatermark
        self.relationshipObservedAt = relationshipObservedAt
        self.sessionOutcomeGeneratedAt = sessionOutcomeGeneratedAt
        self.sessionWorkModelLatestSemanticInferenceCreatedAt = sessionWorkModelLatestSemanticInferenceCreatedAt
        self.projectionGeneratedAt = projectionGeneratedAt
        self.state = state
    }
}
