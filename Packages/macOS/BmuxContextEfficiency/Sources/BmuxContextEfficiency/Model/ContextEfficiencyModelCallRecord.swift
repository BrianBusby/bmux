public import Foundation

/// A model-call telemetry fact imported from Codex rollout JSONL.
public struct ContextEfficiencyModelCallRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable model-call identifier derived from source evidence.
    public var id: String
    /// Thread that owns this model-call telemetry event.
    public var threadID: String
    /// Event timestamp when the rollout supplied one.
    public var timestamp: Date?
    /// Token counters observed for the call.
    public var tokenUsage: ContextEfficiencyTokenUsage
    /// Source evidence location for the telemetry event.
    public var sourceReference: ContextEfficiencySourceReference
    /// Parser or event source confidence label.
    public var telemetryConfidence: String

    /// Creates a model-call telemetry record.
    public init(
        id: String,
        threadID: String,
        timestamp: Date?,
        tokenUsage: ContextEfficiencyTokenUsage,
        sourceReference: ContextEfficiencySourceReference,
        telemetryConfidence: String
    ) {
        self.id = id
        self.threadID = threadID
        self.timestamp = timestamp
        self.tokenUsage = tokenUsage
        self.sourceReference = sourceReference
        self.telemetryConfidence = telemetryConfidence
    }
}
