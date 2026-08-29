import Foundation

/// One explicit text fact aggregated from a turn outcome into a session outcome.
public struct ProvenanceSessionOutcomeTextFact: Codable, Equatable, Sendable {
    /// Stable item identifier.
    public let id: String

    /// Factual item kind.
    public let kind: String

    /// Text copied from accepted evidence.
    public let text: String

    /// Turn whose outcome supplied this fact.
    public let sourceTurnID: String

    /// Exact turn-outcome revision that supplied this fact.
    public let sourceTurnOutcomeRevisionID: String

    /// Supporting evidence references for this fact.
    public let evidence: [ProvenanceTurnOutcomeEvidenceReference]

    /// Creates an aggregated text fact.
    public init(
        id: String,
        kind: String,
        text: String,
        sourceTurnID: String,
        sourceTurnOutcomeRevisionID: String,
        evidence: [ProvenanceTurnOutcomeEvidenceReference]
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.sourceTurnID = sourceTurnID
        self.sourceTurnOutcomeRevisionID = sourceTurnOutcomeRevisionID
        self.evidence = evidence
    }
}
