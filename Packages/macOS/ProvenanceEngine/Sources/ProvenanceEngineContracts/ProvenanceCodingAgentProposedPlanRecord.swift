import Foundation

/// Provider-emitted proposed plan prose, which is not an execution checklist.
///
/// Provider identifiers are carried as received, not inferred from timing.
/// The containing ledger event supplies the observation time and evidence scope.
public struct ProvenanceCodingAgentProposedPlanRecord: Codable, Equatable, Sendable {
    /// Session that owns the observation.
    public let sessionID: String
    /// Originating provider.
    public let provider: String
    /// Provider session identity, if explicitly available.
    public let providerSessionID: String?
    /// Provider turn identity, if explicitly available.
    public let providerTurnID: String?
    /// Provider item identity, if explicitly available.
    public let providerItemID: String?
    /// Observed proposed prose.
    public let text: String
    /// Whether the observation omitted part of the provider prose.
    public let truncated: Bool

    /// True only when all provider identifiers are explicit, canonical and bounded.
    /// This validates their shape; it does not infer a relationship to a turn.
    public var hasValidProviderIdentity: Bool {
        [providerSessionID, providerTurnID, providerItemID].allSatisfy { value in
            guard let value, !value.isEmpty, value.utf8.count <= 256 else { return false }
            return value == value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Creates a proposed-plan observation without inferring missing identity.
    public init(sessionID: String, provider: String, providerSessionID: String? = nil,
                providerTurnID: String? = nil, providerItemID: String? = nil,
                text: String, truncated: Bool) {
        self.sessionID = sessionID
        self.provider = provider
        self.providerSessionID = providerSessionID
        self.providerTurnID = providerTurnID
        self.providerItemID = providerItemID
        self.text = text
        self.truncated = truncated
    }
}
