/// One file or artifact path explicitly attributed to a turn.
public struct ProvenanceTurnOutcomeArtifact: Codable, Equatable, Sendable {
    /// Stable artifact fact identifier.
    public let id: String

    /// Repository-relative or observed path.
    public let path: String

    /// File change status, when accepted file-change evidence is linked.
    public let status: String?

    /// Linked file-change identifier, when present.
    public let fileChangeID: String?

    /// Linked change-set identifier, when present.
    public let changeSetID: String?

    /// Supporting evidence references for this artifact fact.
    public let evidence: [ProvenanceTurnOutcomeEvidenceReference]

    /// Creates an attributed artifact fact.
    public init(
        id: String,
        path: String,
        status: String?,
        fileChangeID: String?,
        changeSetID: String?,
        evidence: [ProvenanceTurnOutcomeEvidenceReference]
    ) {
        self.id = id
        self.path = path
        self.status = status
        self.fileChangeID = fileChangeID
        self.changeSetID = changeSetID
        self.evidence = evidence
    }
}
