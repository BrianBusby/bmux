import Foundation

/// Completeness state for related-session projections and briefs.
public struct ProvenanceRelatedSessionCompleteness: Codable, Equatable, Sendable {
    /// Overall status such as `complete`, `partial`, or `empty`.
    public let status: String

    /// Latest accepted event-ledger sequence evaluated by this model.
    public let evaluatedThroughSequence: Int?

    /// Field-level availability states.
    public let fields: [ProvenanceRelatedSessionAvailability]

    /// Stable notes describing read-model boundaries.
    public let notes: [String]

    /// Creates related-session completeness metadata.
    public init(
        status: String,
        evaluatedThroughSequence: Int?,
        fields: [ProvenanceRelatedSessionAvailability],
        notes: [String]
    ) {
        self.status = status
        self.evaluatedThroughSequence = evaluatedThroughSequence
        self.fields = fields
        self.notes = notes
    }
}
