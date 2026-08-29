import Foundation

/// One completed command aggregated from a turn outcome into a session outcome.
public struct ProvenanceSessionOutcomeCommand: Codable, Equatable, Sendable {
    /// Stable session-level command fact identifier.
    public let id: String

    /// Turn whose outcome supplied this command.
    public let sourceTurnID: String

    /// Exact turn-outcome revision that supplied this command.
    public let sourceTurnOutcomeRevisionID: String

    /// Turn-level command fact.
    public let command: ProvenanceTurnOutcomeCommand

    /// Creates an aggregated command fact.
    public init(
        id: String,
        sourceTurnID: String,
        sourceTurnOutcomeRevisionID: String,
        command: ProvenanceTurnOutcomeCommand
    ) {
        self.id = id
        self.sourceTurnID = sourceTurnID
        self.sourceTurnOutcomeRevisionID = sourceTurnOutcomeRevisionID
        self.command = command
    }
}
