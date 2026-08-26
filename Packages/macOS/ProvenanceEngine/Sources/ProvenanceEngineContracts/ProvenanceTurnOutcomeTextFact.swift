/// One explicit text fact in a deterministic turn outcome.
public struct ProvenanceTurnOutcomeTextFact: Codable, Equatable, Sendable {
    /// Stable item identifier.
    public let id: String

    /// Factual item kind.
    public let kind: String

    /// Text copied from accepted evidence.
    public let text: String

    /// Supporting evidence references for this fact.
    public let evidence: [ProvenanceTurnOutcomeEvidenceReference]

    /// Creates an explicit text fact.
    public init(
        id: String,
        kind: String,
        text: String,
        evidence: [ProvenanceTurnOutcomeEvidenceReference]
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.evidence = evidence
    }
}
