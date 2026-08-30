import Foundation

/// One typed factual reason supporting an artifact-collision candidate.
public struct ProvenanceArtifactCollisionReason: Codable, Equatable, Sendable {
    /// Kind of factual relationship represented by this reason.
    public let kind: ProvenanceArtifactCollisionReasonKind

    /// Target-side value involved in the relationship, when applicable.
    public let targetValue: String?

    /// Related-side value involved in the relationship, when applicable.
    public let relatedValue: String?

    /// Latest time this reason was observed, when derivable from accepted evidence.
    public let observedAt: Date?

    /// Evidence references supporting the reason.
    public let evidence: [ProvenanceArtifactCollisionEvidenceReference]

    /// Creates a candidate reason.
    public init(
        kind: ProvenanceArtifactCollisionReasonKind,
        targetValue: String? = nil,
        relatedValue: String? = nil,
        observedAt: Date? = nil,
        evidence: [ProvenanceArtifactCollisionEvidenceReference]
    ) {
        self.kind = kind
        self.targetValue = targetValue
        self.relatedValue = relatedValue
        self.observedAt = observedAt
        self.evidence = evidence
    }
}
