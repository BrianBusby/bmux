import Foundation

/// Current-state projection for one provider thread associated with a provenance session.
public struct ProvenanceCodingAgentThreadRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable thread projection identifier.
    public let id: String

    /// Provenance session that owns the provider thread.
    public let sessionID: String

    /// Provider name, such as `codex`.
    public let provider: String

    /// Provider-native thread identifier.
    public let providerThreadID: String

    /// Worktree associated with the thread, when known.
    public let worktreeID: String?

    /// Evidence class behind this thread identity.
    public let source: ProvenanceSource

    /// Confidence in this thread identity.
    public let confidence: ProvenanceConfidence

    /// First observed time for this thread.
    public let firstObservedAt: Date

    /// Last projection update time.
    public let updatedAt: Date

    /// Creates a coding-agent thread projection record.
    public init(
        id: String,
        sessionID: String,
        provider: String,
        providerThreadID: String,
        worktreeID: String? = nil,
        source: ProvenanceSource,
        confidence: ProvenanceConfidence,
        firstObservedAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.sessionID = sessionID
        self.provider = provider
        self.providerThreadID = providerThreadID
        self.worktreeID = worktreeID
        self.source = source
        self.confidence = confidence
        self.firstObservedAt = firstObservedAt
        self.updatedAt = updatedAt
    }
}
