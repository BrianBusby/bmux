public import Foundation

/// A tool-call fact imported from a Codex rollout line.
public struct ContextEfficiencyToolCallRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable tool-call record identifier derived from source evidence.
    public var id: String
    /// Thread that owns this tool call.
    public var threadID: String
    /// Codex call identifier when present.
    public var callID: String?
    /// Tool name when present.
    public var toolName: String?
    /// Bounded command summary extracted from shell-like arguments.
    public var commandSummary: String?
    /// Byte count of the raw arguments string, not the arguments themselves.
    public var argumentsByteCount: Int64
    /// Event timestamp when the rollout supplied one.
    public var timestamp: Date?
    /// Source evidence location for the tool call.
    public var sourceReference: ContextEfficiencySourceReference

    /// Creates a tool-call record.
    public init(
        id: String,
        threadID: String,
        callID: String?,
        toolName: String?,
        commandSummary: String?,
        argumentsByteCount: Int64,
        timestamp: Date?,
        sourceReference: ContextEfficiencySourceReference
    ) {
        self.id = id
        self.threadID = threadID
        self.callID = callID
        self.toolName = toolName
        self.commandSummary = commandSummary
        self.argumentsByteCount = argumentsByteCount
        self.timestamp = timestamp
        self.sourceReference = sourceReference
    }
}
