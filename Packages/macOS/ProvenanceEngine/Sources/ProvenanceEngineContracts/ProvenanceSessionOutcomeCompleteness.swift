import Foundation

/// Completeness metadata for the deterministic session-outcome projection.
public struct ProvenanceSessionOutcomeCompleteness: Codable, Equatable, Sendable {
    /// Overall completeness state for the projection.
    public let status: String

    /// Latest accepted event sequence evaluated by the projector.
    public let evaluatedThroughSequence: Int?

    /// Per-field availability metadata.
    public let fields: [ProvenanceSessionOutcomeAvailability]

    /// Stable notes about deliberate projection limits.
    public let notes: [String]

    /// Creates completeness metadata.
    public init(
        status: String,
        evaluatedThroughSequence: Int?,
        fields: [ProvenanceSessionOutcomeAvailability],
        notes: [String] = []
    ) {
        self.status = status
        self.evaluatedThroughSequence = evaluatedThroughSequence
        self.fields = fields
        self.notes = notes
    }
}
