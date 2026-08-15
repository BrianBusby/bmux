import Foundation

/// Observable submitted input for one coding-agent turn.
public struct ProvenanceCodingAgentPromptRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable prompt evidence projection identifier.
    public let id: String

    /// Provenance session that owns the prompt.
    public let sessionID: String

    /// Provider thread projection identifier, when known.
    public let threadID: String?

    /// Provider turn projection identifier, when known.
    public let turnID: String?

    /// Provider name, such as `codex`.
    public let provider: String

    /// Submitted prompt text.
    public let text: String

    /// Prompt submission time.
    public let submittedAt: Date

    /// Evidence class behind this prompt.
    public let source: ProvenanceSource

    /// Confidence in this prompt evidence.
    public let confidence: ProvenanceConfidence

    /// Creates a submitted prompt projection record.
    public init(
        id: String,
        sessionID: String,
        threadID: String? = nil,
        turnID: String? = nil,
        provider: String,
        text: String,
        submittedAt: Date,
        source: ProvenanceSource,
        confidence: ProvenanceConfidence
    ) {
        self.id = id
        self.sessionID = sessionID
        self.threadID = threadID
        self.turnID = turnID
        self.provider = provider
        self.text = text
        self.submittedAt = submittedAt
        self.source = source
        self.confidence = confidence
    }
}
