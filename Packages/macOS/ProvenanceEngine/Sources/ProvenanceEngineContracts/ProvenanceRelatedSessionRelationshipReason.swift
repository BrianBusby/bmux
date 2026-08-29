import Foundation

/// One inspectable deterministic reason connecting a related session to a target.
public struct ProvenanceRelatedSessionRelationshipReason: Codable, Equatable, Sendable {
    /// Typed relationship kind.
    public let kind: ProvenanceRelatedSessionRelationshipKind

    /// Observed or projection-derived value on the target side.
    public let targetValue: String?

    /// Observed or projection-derived value on the related-session side.
    public let relatedValue: String?

    /// Session-tree distance when the reason is based on ancestry.
    public let relationshipDepth: Int?

    /// Accepted evidence or projection references supporting this reason.
    public let evidence: [ProvenanceRelatedSessionEvidenceReference]

    /// Timestamp of the latest accepted evidence used for the reason, when known.
    public let observedAt: Date?

    /// Creates a related-session relationship reason.
    public init(
        kind: ProvenanceRelatedSessionRelationshipKind,
        targetValue: String?,
        relatedValue: String?,
        relationshipDepth: Int? = nil,
        evidence: [ProvenanceRelatedSessionEvidenceReference],
        observedAt: Date?
    ) {
        self.kind = kind
        self.targetValue = targetValue
        self.relatedValue = relatedValue
        self.relationshipDepth = relationshipDepth
        self.evidence = evidence
        self.observedAt = observedAt
    }
}
