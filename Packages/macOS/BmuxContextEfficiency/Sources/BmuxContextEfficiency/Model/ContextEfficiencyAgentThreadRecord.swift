public import Foundation

/// A logical Codex thread imported into the context-efficiency store.
public struct ContextEfficiencyAgentThreadRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable bmux context-efficiency thread identifier.
    public var id: String
    /// External Codex thread or rollout identifier when known.
    public var externalThreadID: String?
    /// Rollout JSONL path that supplied the thread facts.
    public var rolloutPath: String?
    /// Model name observed for the thread when known.
    public var model: String?
    /// Reasoning level observed for the thread when known.
    public var reasoningEffort: String?
    /// Working directory observed for the thread when known.
    public var cwd: String?
    /// First imported event timestamp for the thread.
    public var firstObservedAt: Date?
    /// Most recent imported event timestamp for the thread.
    public var lastObservedAt: Date?
    /// Latest cumulative total token count observed for the thread.
    public var cumulativeTotalTokens: Int64?
    /// Number of non-duplicate model-call telemetry rows stored for the thread.
    public var modelCallCount: Int
    /// Number of compaction events observed for the thread.
    public var compactionCount: Int

    /// Creates an imported thread record.
    public init(
        id: String,
        externalThreadID: String?,
        rolloutPath: String?,
        model: String?,
        reasoningEffort: String?,
        cwd: String?,
        firstObservedAt: Date?,
        lastObservedAt: Date?,
        cumulativeTotalTokens: Int64?,
        modelCallCount: Int,
        compactionCount: Int
    ) {
        self.id = id
        self.externalThreadID = externalThreadID
        self.rolloutPath = rolloutPath
        self.model = model
        self.reasoningEffort = reasoningEffort
        self.cwd = cwd
        self.firstObservedAt = firstObservedAt
        self.lastObservedAt = lastObservedAt
        self.cumulativeTotalTokens = cumulativeTotalTokens
        self.modelCallCount = modelCallCount
        self.compactionCount = compactionCount
    }
}
