/// One explicitly observed plan item in a turn outcome.
public struct ProvenanceTurnOutcomePlanItem: Codable, Equatable, Sendable {
    /// Stable item identifier.
    public let id: String

    /// Provider or normalized plan step status.
    public let status: String

    /// Plan step text copied from accepted evidence.
    public let text: String

    /// Supporting evidence references for this plan item.
    public let evidence: [ProvenanceTurnOutcomeEvidenceReference]

    /// Creates a plan item fact.
    public init(
        id: String,
        status: String,
        text: String,
        evidence: [ProvenanceTurnOutcomeEvidenceReference]
    ) {
        self.id = id
        self.status = status
        self.text = text
        self.evidence = evidence
    }
}
