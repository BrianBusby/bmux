import Foundation

/// Compact factual reference for an observed coding-agent turn.
public struct ProvenanceFactualSessionProjectionTurnReference: Codable, Equatable, Sendable {
    /// Stable Provenance Engine turn projection identifier.
    public let turnID: String

    /// Provider thread projection identifier, when known.
    public let threadID: String?

    /// Provider name, such as `codex`.
    public let provider: String

    /// Provider-native turn identifier.
    public let providerTurnID: String

    /// Factual lifecycle status, such as `started`, `completed`, or `failed`.
    public let status: String

    /// Turn start time, when observed.
    public let startedAt: Date?

    /// Turn completion or failure time, when observed.
    public let completedAt: Date?

    /// Last projection update time.
    public let updatedAt: Date

    /// Creates a compact turn reference.
    public init(
        turnID: String,
        threadID: String? = nil,
        provider: String,
        providerTurnID: String,
        status: String,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        updatedAt: Date
    ) {
        self.turnID = turnID
        self.threadID = threadID
        self.provider = provider
        self.providerTurnID = providerTurnID
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.updatedAt = updatedAt
    }

    /// Creates a compact reference from the lower-level turn projection record.
    public init(turn: ProvenanceCodingAgentTurnRecord) {
        self.init(
            turnID: turn.id,
            threadID: turn.threadID,
            provider: turn.provider,
            providerTurnID: turn.providerTurnID,
            status: turn.status,
            startedAt: turn.startedAt,
            completedAt: turn.completedAt,
            updatedAt: turn.updatedAt
        )
    }
}
