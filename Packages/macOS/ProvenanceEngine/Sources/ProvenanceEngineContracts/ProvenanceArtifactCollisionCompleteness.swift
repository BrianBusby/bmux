/// Completeness metadata for an artifact-collision projection or candidate.
public struct ProvenanceArtifactCollisionCompleteness: Codable, Equatable, Sendable {
    /// Aggregate status, such as `complete`, `partial`, or `empty`.
    public let status: String

    /// Latest ledger sequence evaluated by this projection.
    public let evaluatedThroughSequence: Int?

    /// Field-level availability records.
    public let fields: [ProvenanceArtifactCollisionAvailability]

    /// Bounded notes about deterministic rules and unsupported cases.
    public let notes: [String]

    /// Creates completeness metadata.
    public init(
        status: String,
        evaluatedThroughSequence: Int?,
        fields: [ProvenanceArtifactCollisionAvailability],
        notes: [String]
    ) {
        self.status = status
        self.evaluatedThroughSequence = evaluatedThroughSequence
        self.fields = fields
        self.notes = notes
    }
}
