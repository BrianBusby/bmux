public import Foundation

/// Raw token telemetry fact retained separately from the model-call projection.
public struct ContextEfficiencyTokenTelemetryRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable telemetry identifier derived from source evidence.
    public var id: String
    /// Thread that owns this telemetry event.
    public var threadID: String
    /// Event timestamp when the rollout supplied one.
    public var timestamp: Date?
    /// Token counters observed for the event.
    public var tokenUsage: ContextEfficiencyTokenUsage
    /// Source evidence location for the telemetry event.
    public var sourceReference: ContextEfficiencySourceReference

    /// Creates a token telemetry record.
    public init(
        id: String,
        threadID: String,
        timestamp: Date?,
        tokenUsage: ContextEfficiencyTokenUsage,
        sourceReference: ContextEfficiencySourceReference
    ) {
        self.id = id
        self.threadID = threadID
        self.timestamp = timestamp
        self.tokenUsage = tokenUsage
        self.sourceReference = sourceReference
    }
}
