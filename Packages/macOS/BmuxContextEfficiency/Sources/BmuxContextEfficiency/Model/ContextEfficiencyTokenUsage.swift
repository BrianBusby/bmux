import Foundation

/// Token counters observed for a Codex model-call telemetry event.
public struct ContextEfficiencyTokenUsage: Codable, Equatable, Sendable {
    /// Total input tokens when the telemetry source exposes them.
    public var inputTokens: Int64?
    /// Cached input tokens when the telemetry source exposes them.
    public var cachedInputTokens: Int64?
    /// Non-cached input tokens when the telemetry source exposes them.
    public var nonCachedInputTokens: Int64?
    /// Output tokens when the telemetry source exposes them.
    public var outputTokens: Int64?
    /// Reasoning-output tokens when the telemetry source exposes them.
    public var reasoningOutputTokens: Int64?
    /// Total tokens when the telemetry source exposes a cumulative total.
    public var totalTokens: Int64?
    /// Estimated current context tokens when the telemetry source exposes them.
    public var estimatedContextTokens: Int64?
    /// Context-window capacity when the telemetry source exposes it.
    public var contextWindowTokens: Int64?

    /// Creates a token usage value.
    ///
    /// - Parameters:
    ///   - inputTokens: Total input tokens when available.
    ///   - cachedInputTokens: Cached input tokens when available.
    ///   - nonCachedInputTokens: Non-cached input tokens when available.
    ///   - outputTokens: Output tokens when available.
    ///   - reasoningOutputTokens: Reasoning-output tokens when available.
    ///   - totalTokens: Total tokens when available.
    ///   - estimatedContextTokens: Estimated current context tokens when available.
    ///   - contextWindowTokens: Context-window capacity when available.
    public init(
        inputTokens: Int64? = nil,
        cachedInputTokens: Int64? = nil,
        nonCachedInputTokens: Int64? = nil,
        outputTokens: Int64? = nil,
        reasoningOutputTokens: Int64? = nil,
        totalTokens: Int64? = nil,
        estimatedContextTokens: Int64? = nil,
        contextWindowTokens: Int64? = nil
    ) {
        self.inputTokens = inputTokens
        self.cachedInputTokens = cachedInputTokens
        self.nonCachedInputTokens = nonCachedInputTokens
        self.outputTokens = outputTokens
        self.reasoningOutputTokens = reasoningOutputTokens
        self.totalTokens = totalTokens
        self.estimatedContextTokens = estimatedContextTokens
        self.contextWindowTokens = contextWindowTokens
    }

    var hasAnyTokenCount: Bool {
        inputTokens != nil ||
            cachedInputTokens != nil ||
            nonCachedInputTokens != nil ||
            outputTokens != nil ||
            reasoningOutputTokens != nil ||
            totalTokens != nil ||
            estimatedContextTokens != nil ||
            contextWindowTokens != nil
    }

    var duplicateFingerprint: String {
        [
            inputTokens,
            cachedInputTokens,
            nonCachedInputTokens,
            outputTokens,
            reasoningOutputTokens,
            totalTokens,
            estimatedContextTokens,
            contextWindowTokens,
        ]
        .map { value in
            value.map(String.init) ?? "nil"
        }
        .joined(separator: ":")
    }
}
