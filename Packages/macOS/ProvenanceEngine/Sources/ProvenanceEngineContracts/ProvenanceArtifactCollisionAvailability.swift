/// Availability state for one factual field in an artifact-collision projection.
public struct ProvenanceArtifactCollisionAvailability: Codable, Equatable, Sendable {
    /// Stable field name evaluated by the projection.
    public let field: String

    /// Availability status, such as `observed`, `partial`, `not_observed`, or `not_supported`.
    public let status: String

    /// Machine-stable reason when the field is unavailable or partial.
    public let reason: String?

    /// Evidence references supporting the field state.
    public let evidence: [ProvenanceArtifactCollisionEvidenceReference]

    /// Creates one field availability record.
    public init(
        field: String,
        status: String,
        reason: String? = nil,
        evidence: [ProvenanceArtifactCollisionEvidenceReference] = []
    ) {
        self.field = field
        self.status = status
        self.reason = reason
        self.evidence = evidence
    }
}
