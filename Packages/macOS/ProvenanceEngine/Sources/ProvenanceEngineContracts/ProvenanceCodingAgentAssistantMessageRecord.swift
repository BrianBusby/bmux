import Foundation

/// Completed visible assistant output emitted by a provider-supported surface.
public struct ProvenanceCodingAgentAssistantMessageRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable assistant-message projection identifier.
    public let id: String

    /// Provenance session that owns the assistant output.
    public let sessionID: String

    /// Provider thread projection identifier, when known.
    public let threadID: String?

    /// Provider turn projection identifier, when known.
    public let turnID: String?

    /// Provider name, such as `codex`.
    public let provider: String

    /// Provider item identifier, when available.
    public let itemID: String?

    /// Provider-emitted visible assistant output text.
    public let text: String

    /// Time this completed assistant output was observed.
    public let completedAt: Date

    /// Evidence class behind this assistant output.
    public let source: ProvenanceSource

    /// Confidence in this assistant-output evidence.
    public let confidence: ProvenanceConfidence

    /// Creates a visible assistant-output projection record.
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
