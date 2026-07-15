public import Foundation

/// A tool-output fact imported from a Codex rollout line.
public struct ContextEfficiencyToolOutputRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable tool-output record identifier derived from source evidence.
    public var id: String
    /// Thread that owns this tool output.
    public var threadID: String
    /// Codex call identifier when present.
    public var callID: String?
    /// Byte count of the output string, not the output itself.
    public var outputByteCount: Int64
    /// Estimated original tokens when bmux output-reduction metadata is present.
    public var estimatedOriginalTokens: Int64
    /// Count of recoverable raw-output references mentioned in the reduced output.
    public var rawOutputReferenceCount: Int
    /// Event timestamp when the rollout supplied one.
    public var timestamp: Date?
    /// Source evidence location for the tool output.
    public var sourceReference: ContextEfficiencySourceReference

    /// Creates a tool-output record.
    public init(
        id: String,
        threadID: String,
        callID: String?,
        outputByteCount: Int64,
        estimatedOriginalTokens: Int64,
        rawOutputReferenceCount: Int,
        timestamp: Date?,
        sourceReference: ContextEfficiencySourceReference
    ) {
        self.id = id
        self.threadID = threadID
        self.callID = callID
        self.outputByteCount = outputByteCount
        self.estimatedOriginalTokens = estimatedOriginalTokens
        self.rawOutputReferenceCount = rawOutputReferenceCount
        self.timestamp = timestamp
        self.sourceReference = sourceReference
    }
}
