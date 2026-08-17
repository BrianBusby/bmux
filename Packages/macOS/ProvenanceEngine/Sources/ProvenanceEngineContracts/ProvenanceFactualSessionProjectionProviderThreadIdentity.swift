import Foundation

/// Compact factual provider-thread identity observed for one provenance session.
public struct ProvenanceFactualSessionProjectionProviderThreadIdentity: Codable, Equatable, Sendable {
    /// Stable Provenance Engine thread projection identifier.
    public let threadID: String

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

    /// Creates a compact provider-thread identity reference.
    public init(
        threadID: String,
        provider: String,
        providerThreadID: String,
        worktreeID: String? = nil,
        source: ProvenanceSource,
        confidence: ProvenanceConfidence,
        firstObservedAt: Date,
        updatedAt: Date
    ) {
        self.threadID = threadID
        self.provider = provider
        self.providerThreadID = providerThreadID
        self.worktreeID = worktreeID
        self.source = source
        self.confidence = confidence
        self.firstObservedAt = firstObservedAt
        self.updatedAt = updatedAt
    }

    /// Creates a compact identity from the lower-level thread projection record.
    public init(thread: ProvenanceCodingAgentThreadRecord) {
        self.init(
            threadID: thread.id,
            provider: thread.provider,
            providerThreadID: thread.providerThreadID,
            worktreeID: thread.worktreeID,
            source: thread.source,
            confidence: thread.confidence,
            firstObservedAt: thread.firstObservedAt,
            updatedAt: thread.updatedAt
        )
    }
}
