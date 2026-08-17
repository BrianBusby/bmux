import Foundation

/// Current-state projection for one provider turn in a coding-agent thread.
public struct ProvenanceCodingAgentTurnRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable turn projection identifier.
    public let id: String

    /// Provenance session that owns the turn.
    public let sessionID: String

    /// Provider thread projection identifier, when known.
    public let threadID: String?

    /// Provider name, such as `codex`.
    public let provider: String

    /// Provider-native turn identifier.
    public let providerTurnID: String

    /// Factual lifecycle status, such as `started`, `completed`, or `failed`.
    public let status: String

    /// Model selected for the turn, when known.
    public let model: String?

    /// Provider effort or reasoning setting, when known.
    public let effort: String?

    /// Turn start time, when observed.
    public let startedAt: Date?

    /// Turn completion or failure time, when observed.
    public let completedAt: Date?

    /// Last projection update time.
    public let updatedAt: Date

    /// Evidence class behind this turn identity.
    public let source: ProvenanceSource

    /// Confidence in this turn identity.
    public let confidence: ProvenanceConfidence

    /// Creates a coding-agent turn projection record.
    public init(
        id: String,
        sessionID: String,
        threadID: String? = nil,
        provider: String,
        providerTurnID: String,
        status: String,
        model: String? = nil,
        effort: String? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        updatedAt: Date,
        source: ProvenanceSource,
        confidence: ProvenanceConfidence
    ) {
        self.id = id
        self.sessionID = sessionID
        self.threadID = threadID
        self.provider = provider
        self.providerTurnID = providerTurnID
        self.status = status
        self.model = model
        self.effort = effort
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.updatedAt = updatedAt
        self.source = source
        self.confidence = confidence
    }
}
