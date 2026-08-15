import Foundation

/// Completed visible reasoning summary emitted by a provider-supported surface.
public struct ProvenanceCodingAgentReasoningSummaryRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable reasoning-summary projection identifier.
    public let id: String

    /// Provenance session that owns the summary.
    public let sessionID: String

    /// Provider thread projection identifier, when known.
    public let threadID: String?

    /// Provider turn projection identifier, when known.
    public let turnID: String?

    /// Provider name, such as `codex`.
    public let provider: String

    /// Provider item identifier, when available.
    public let itemID: String?

    /// Provider-emitted visible summary text.
    public let text: String

    /// Time this completed summary was observed.
    public let completedAt: Date

    /// Evidence class behind this visible summary.
    public let source: ProvenanceSource

    /// Confidence in this visible-summary evidence.
    public let confidence: ProvenanceConfidence

    /// Creates a visible reasoning-summary projection record.
    public init(
        id: String,
        sessionID: String,
        threadID: String? = nil,
        turnID: String? = nil,
        provider: String,
        itemID: String? = nil,
        text: String,
        completedAt: Date,
        source: ProvenanceSource,
        confidence: ProvenanceConfidence
    ) {
        self.id = id
        self.sessionID = sessionID
        self.threadID = threadID
        self.turnID = turnID
        self.provider = provider
        self.itemID = itemID
        self.text = text
        self.completedAt = completedAt
        self.source = source
        self.confidence = confidence
    }
}
