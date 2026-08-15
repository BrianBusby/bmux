import Foundation

/// Factual, deterministic work snapshot for one coding-agent session.
public struct ProvenanceSessionWorkModelSnapshot: Codable, Equatable, Sendable {
    /// Monotonically increasing ledger revision current when the snapshot was read.
    public let revision: Int?

    /// Provenance session identity.
    public let session: ProvenanceSessionRecord

    /// Provider thread identities explicitly observed for the session.
    public let providerThreads: [ProvenanceCodingAgentThreadRecord]

    /// Observed turns with only evidence directly linked to each turn.
    public let turns: [ProvenanceSessionWorkModelTurnSnapshot]

    /// Creates a factual session work model snapshot.
    public init(
        revision: Int?,
        session: ProvenanceSessionRecord,
        providerThreads: [ProvenanceCodingAgentThreadRecord],
        turns: [ProvenanceSessionWorkModelTurnSnapshot]
    ) {
        self.revision = revision
        self.session = session
        self.providerThreads = providerThreads
        self.turns = turns
    }
}
