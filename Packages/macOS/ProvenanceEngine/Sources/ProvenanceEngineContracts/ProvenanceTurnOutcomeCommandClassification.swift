/// Deterministic classification assigned to a command fact.
public struct ProvenanceTurnOutcomeCommandClassification: Codable, Equatable, Sendable {
    /// Stable command class, such as `test`, `build`, `git_inspection`, or `unsupported`.
    public let kind: String

    /// Version of the deterministic command-classification rule.
    public let ruleVersion: String

    /// Whether the rule produced a supported classification.
    public let supported: Bool

    /// Creates command classification metadata.
    public init(kind: String, ruleVersion: String, supported: Bool) {
        self.kind = kind
        self.ruleVersion = ruleVersion
        self.supported = supported
    }
}
