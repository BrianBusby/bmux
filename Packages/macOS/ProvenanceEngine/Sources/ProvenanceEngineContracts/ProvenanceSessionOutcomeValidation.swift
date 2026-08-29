import Foundation

/// One validation attempt aggregated from a turn outcome into a session outcome.
public struct ProvenanceSessionOutcomeValidation: Codable, Equatable, Sendable {
    /// Stable session-level validation fact identifier.
    public let id: String

    /// Turn whose outcome supplied this validation attempt.
    public let sourceTurnID: String

    /// Exact turn-outcome revision that supplied this validation attempt.
    public let sourceTurnOutcomeRevisionID: String

    /// Turn-level validation fact.
    public let validation: ProvenanceTurnOutcomeValidation

    /// Creates an aggregated validation-attempt fact.
    public init(
        id: String,
        sourceTurnID: String,
        sourceTurnOutcomeRevisionID: String,
        validation: ProvenanceTurnOutcomeValidation
    ) {
        self.id = id
        self.sourceTurnID = sourceTurnID
        self.sourceTurnOutcomeRevisionID = sourceTurnOutcomeRevisionID
        self.validation = validation
    }
}
