/// Availability metadata for one optional turn-outcome field.
public struct ProvenanceTurnOutcomeAvailability: Codable, Equatable, Sendable {
    /// Stable field name, such as `objective` or `validations_attempted`.
    public let field: String

    /// Availability state: `observed`, `not_observed`, `partial`, or `unavailable`.
    public let status: String

    /// Stable reason code for unavailable or partial fields.
    public let reason: String?

    /// Evidence used to determine availability.
    public let evidence: [ProvenanceTurnOutcomeEvidenceReference]

    /// Creates availability metadata.
    public init(
        field: String,
        status: String,
        reason: String? = nil,
        evidence: [ProvenanceTurnOutcomeEvidenceReference] = []
    ) {
        self.field = field
        self.status = status
        self.reason = reason
        self.evidence = evidence
    }
}
