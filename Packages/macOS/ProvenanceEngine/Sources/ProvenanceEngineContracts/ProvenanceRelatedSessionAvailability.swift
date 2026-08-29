import Foundation

/// Availability state for one related-session field.
public struct ProvenanceRelatedSessionAvailability: Codable, Equatable, Sendable {
    /// Stable field name.
    public let field: String

    /// Availability status such as `observed`, `not_observed`, or `partial`.
    public let status: String

    /// Stable reason code when the field is unavailable or partial.
    public let reason: String?

    /// Evidence supporting the field availability.
    public let evidence: [ProvenanceRelatedSessionEvidenceReference]

    /// Creates a field availability state.
    public init(
        field: String,
        status: String,
        reason: String? = nil,
        evidence: [ProvenanceRelatedSessionEvidenceReference] = []
    ) {
        self.field = field
        self.status = status
        self.reason = reason
        self.evidence = evidence
    }
}
