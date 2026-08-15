import Foundation

/// Factual, deterministic projection snapshot for one coding-agent session.
public struct ProvenanceFactualSessionProjectionSnapshot: Codable, Equatable, Sendable {
    /// Monotonically increasing ledger revision current at read time.
    public let revision: Int?

    /// Provenance session identity.
    public let session: ProvenanceSessionRecord

    /// Provider thread identities explicitly observed for the session.
    public let providerThreads: [ProvenanceCodingAgentThreadRecord]

    /// Observed turns with only evidence directly linked to each turn.
    public let turns: [ProvenanceFactualSessionProjectionTurnSnapshot]

    /// Creates a factual session projection snapshot.
    public init(
        revision: Int?,
        session: ProvenanceSessionRecord,
        providerThreads: [ProvenanceCodingAgentThreadRecord],
        turns: [ProvenanceFactualSessionProjectionTurnSnapshot]
    ) {
        self.revision = revision
        self.session = session
        self.providerThreads = providerThreads
        self.turns = turns
    }
}
