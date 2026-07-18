public import Foundation

/// Derived command execution candidate from imported Codex tool-call facts.
public struct ContextEfficiencyCommandExecutionRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable command execution identifier derived from the tool-call fact.
    public var id: String
    /// Thread that owns this command candidate.
    public var threadID: String
    /// Codex tool-call identifier when present.
    public var callID: String?
    /// Tool name that produced the command candidate.
    public var toolName: String?
    /// Bounded command text summary.
    public var commandSummary: String?
    /// First executable-like token after leading environment assignments.
    public var normalizedExecutable: String?
    /// Classified command family.
    public var category: ContextEfficiencyCommandCategory
    /// Byte count of the raw tool-call arguments, not the arguments themselves.
    public var argumentsByteCount: Int64
    /// Byte count of the linked tool output when available.
    public var outputByteCount: Int64?
    /// Estimated original output tokens when reduction metadata is present.
    public var estimatedOriginalOutputTokens: Int64?
    /// Count of recoverable raw-output references mentioned by the linked output.
    public var rawOutputReferenceCount: Int
    /// Tool-call timestamp when the rollout supplied one.
    public var startedAt: Date?
    /// Linked tool-output timestamp when the rollout supplied one.
    public var completedAt: Date?
    /// Elapsed seconds between linked tool call and output timestamps.
    public var elapsedSeconds: Double?
    /// Source evidence location for the tool call.
    public var toolCallSourceReference: ContextEfficiencySourceReference
    /// Source evidence location for the linked tool output, if found.
    public var toolOutputSourceReference: ContextEfficiencySourceReference?
    /// Confidence for linking the tool call to the output.
    public var outputAttributionConfidence: ContextEfficiencyAttributionConfidence
    /// Candidate later model call that may have consumed the command output.
    public var attributedModelCall: ContextEfficiencyModelCallAttribution?

    /// Creates a command execution candidate.
    ///
    /// - Parameters:
    ///   - id: Stable command execution identifier derived from the tool-call fact.
    ///   - threadID: Thread that owns this command candidate.
    ///   - callID: Codex tool-call identifier when present.
    ///   - toolName: Tool name that produced the command candidate.
    ///   - commandSummary: Bounded command text summary.
    ///   - normalizedExecutable: First executable-like token after leading environment assignments.
    ///   - category: Classified command family.
    ///   - argumentsByteCount: Byte count of the raw tool-call arguments.
    ///   - outputByteCount: Byte count of the linked tool output when available.
    ///   - estimatedOriginalOutputTokens: Estimated original output tokens when reduction metadata is present.
    ///   - rawOutputReferenceCount: Count of recoverable raw-output references mentioned by the linked output.
    ///   - startedAt: Tool-call timestamp when the rollout supplied one.
    ///   - completedAt: Linked tool-output timestamp when the rollout supplied one.
    ///   - elapsedSeconds: Elapsed seconds between linked tool call and output timestamps.
    ///   - toolCallSourceReference: Source evidence location for the tool call.
    ///   - toolOutputSourceReference: Source evidence location for the linked tool output, if found.
    ///   - outputAttributionConfidence: Confidence for linking the tool call to the output.
    ///   - attributedModelCall: Candidate later model call that may have consumed the command output.
    public init(
        id: String,
        threadID: String,
        callID: String?,
        toolName: String?,
        commandSummary: String?,
        normalizedExecutable: String?,
        category: ContextEfficiencyCommandCategory,
        argumentsByteCount: Int64,
        outputByteCount: Int64?,
        estimatedOriginalOutputTokens: Int64?,
        rawOutputReferenceCount: Int,
        startedAt: Date?,
        completedAt: Date?,
        elapsedSeconds: Double?,
        toolCallSourceReference: ContextEfficiencySourceReference,
        toolOutputSourceReference: ContextEfficiencySourceReference?,
        outputAttributionConfidence: ContextEfficiencyAttributionConfidence,
        attributedModelCall: ContextEfficiencyModelCallAttribution?
    ) {
        self.id = id
        self.threadID = threadID
        self.callID = callID
        self.toolName = toolName
        self.commandSummary = commandSummary
        self.normalizedExecutable = normalizedExecutable
        self.category = category
        self.argumentsByteCount = argumentsByteCount
        self.outputByteCount = outputByteCount
        self.estimatedOriginalOutputTokens = estimatedOriginalOutputTokens
        self.rawOutputReferenceCount = rawOutputReferenceCount
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.elapsedSeconds = elapsedSeconds
        self.toolCallSourceReference = toolCallSourceReference
        self.toolOutputSourceReference = toolOutputSourceReference
        self.outputAttributionConfidence = outputAttributionConfidence
        self.attributedModelCall = attributedModelCall
    }
}
