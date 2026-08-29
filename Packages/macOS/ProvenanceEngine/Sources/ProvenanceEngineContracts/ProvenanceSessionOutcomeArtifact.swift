import Foundation

/// One changed artifact aggregated from a turn outcome into a session outcome.
public struct ProvenanceSessionOutcomeArtifact: Codable, Equatable, Sendable {
    /// Stable session-level artifact fact identifier.
    public let id: String

    /// Turn whose outcome supplied this artifact.
    public let sourceTurnID: String

    /// Exact turn-outcome revision that supplied this artifact.
    public let sourceTurnOutcomeRevisionID: String

    /// Turn-level artifact fact.
    public let artifact: ProvenanceTurnOutcomeArtifact

    /// Creates an aggregated artifact fact.
    public init(
        id: String,
        sourceTurnID: String,
        sourceTurnOutcomeRevisionID: String,
        artifact: ProvenanceTurnOutcomeArtifact
    ) {
        self.id = id
        self.sourceTurnID = sourceTurnID
        self.sourceTurnOutcomeRevisionID = sourceTurnOutcomeRevisionID
        self.artifact = artifact
    }
}
